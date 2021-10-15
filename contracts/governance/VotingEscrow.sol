// SPDX-License-Identifier: MIT
pragma solidity >=0.6.10 <0.8.0;
pragma experimental ABIEncoderV2;

import "@openzeppelinUpgrade/contracts/utils/AddressUpgradeable.sol";
import "@openzeppelinUpgrade/contracts/math/SafeMathUpgradeable.sol";
import "@openzeppelinUpgrade/contracts/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelinUpgrade/contracts/token/ERC20/SafeERC20Upgradeable.sol";
import "@openzeppelinUpgrade/contracts/utils/ReentrancyGuardUpgradeable.sol";
import "@openzeppelinUpgrade/contracts/access/OwnableUpgradeable.sol";

import "../interfaces/IVotingEscrow.sol";

interface IAddressWhitelist {
    function check(address account) external view returns (bool);
}

contract VotingEscrow is IVotingEscrow, ReentrancyGuardUpgradeable, OwnableUpgradeable {
    /// @dev Reserved storage slots for future base contract upgrades
    uint256[32] private _reservedSlots;

    using SafeMathUpgradeable for uint256;
    using SafeERC20Upgradeable for IERC20Upgradeable;

    event LockCreated(address indexed account, uint256 amount, uint256 unlockTime);
    event AmountIncreased(address indexed account, uint256 increasedAmount);
    event UnlockTimeIncreased(address indexed account, uint256 newUnlockTime);
    event Withdrawn(address indexed account, uint256 amount);

    uint256 public override maxTime;
    address public override token;
    uint256 public override releaseRate;  /// rate for 1e9

    string public name;
    string public symbol;

    address public addressWhitelist;

    mapping(address => LockedBalance) public locked;

    /// @notice Mapping of unlockTime => total amount that will be unlocked at unlockTime
    mapping(uint256 => uint256) public scheduledUnlock;

    /// @notice max lock time allowed at the moment
    uint256 public maxTimeAllowed;

    /// @dev UTC time of a day when the fund settles.
    uint256 public override SETTLEMENT_TIME_RATE;
    uint256 public override periodUnit;

    function initialize(
        address token_,
        address addressWhitelist_,
        string memory name_,
        string memory symbol_,
        uint256 maxTime_,
        uint256 maxTimeAllowed_, 
        uint256 periodUnit_) public initializer {

        __Ownable_init();
        name = name_;
        symbol = symbol_;
        token = token_;
        addressWhitelist = addressWhitelist_;
        maxTime = maxTime_;
        require(maxTimeAllowed_ <= maxTime, "Cannot exceed max time");
        maxTimeAllowed = maxTimeAllowed_;
        releaseRate = 4e9;
        periodUnit = periodUnit_;
        SETTLEMENT_TIME_RATE = ((uint256)(14 hours)).mul(1e9).div(1 weeks);
    }

    function getTimestampDropBelow(address account, uint256 threshold)
        external view override returns (uint256)
    {
        LockedBalance memory lockedBalance = locked[account];
        if (lockedBalance.amount == 0 || lockedBalance.amount < threshold) {
            return 0;
        }
        return lockedBalance.unlockTime.sub(
            threshold.mul(maxTime).mul(1e9).div(releaseRate)
            .div(lockedBalance.amount));
    }

    function balanceOf(address account) external view override returns (uint256) {
        return _balanceOfAtTimestamp(account, block.timestamp);
    }

    function totalSupply() external view override returns (uint256) {
        return _totalSupplyAtTimestamp(block.timestamp);
    }

    function getLockedBalance(address account)
        external view override returns (LockedBalance memory)
    {
        return locked[account];
    }

    function balanceOfAtTimestamp(address account, uint256 timestamp)
        external
        view override returns (uint256)
    {
        return _balanceOfAtTimestamp(account, timestamp);
    }

    function totalSupplyAtTimestamp(uint256 timestamp) external view returns (uint256) {
        return _totalSupplyAtTimestamp(timestamp);
    }

    function createLock(
        uint256 amount,
        uint256 unlockTime,
        address,
        bytes memory
    ) external nonReentrant {
        _assertNotContract();
        require(
            unlockTime.add(periodUnit) == _endOfPeriod(unlockTime),
            "Unlock time must be end of a period"
        );

        LockedBalance memory lockedBalance = locked[msg.sender];

        require(amount > 0, "Zero value");
        require(lockedBalance.amount == 0, "Withdraw old tokens first");
        require(unlockTime > block.timestamp, "Can only lock until time in the future");
        require(
            unlockTime <= block.timestamp.add(maxTimeAllowed),
            "Voting lock cannot exceed max lock time"
        );

        scheduledUnlock[unlockTime] = scheduledUnlock[unlockTime].add(amount);
        locked[msg.sender].unlockTime = unlockTime;
        locked[msg.sender].amount = amount;

        IERC20Upgradeable(token).safeTransferFrom(msg.sender, address(this), amount);

        emit LockCreated(msg.sender, amount, unlockTime);
    }

    function increaseAmount(
        address account,
        uint256 amount,
        address,
        bytes memory
    ) external nonReentrant {
        LockedBalance memory lockedBalance = locked[account];

        require(amount > 0, "Zero value");
        require(lockedBalance.unlockTime > block.timestamp, "Cannot add to expired lock");

        scheduledUnlock[lockedBalance.unlockTime] = 
            scheduledUnlock[lockedBalance.unlockTime].add(amount);
        locked[account].amount = lockedBalance.amount.add(amount);

        IERC20Upgradeable(token).safeTransferFrom(msg.sender, address(this), amount);

        emit AmountIncreased(account, amount);
    }

    function increaseUnlockTime(
        uint256 unlockTime,
        address,
        bytes memory
    ) external nonReentrant {
        require(
            unlockTime.add(periodUnit) == _endOfPeriod(unlockTime),
            "Unlock time must be end of a period"
        );
        LockedBalance memory lockedBalance = locked[msg.sender];

        require(lockedBalance.unlockTime > block.timestamp, "Lock expired");
        require(unlockTime > lockedBalance.unlockTime, "Can only increase lock duration");
        require(
            unlockTime <= block.timestamp.add(maxTimeAllowed),
            "Voting lock cannot exceed max lock time"
        );

        scheduledUnlock[lockedBalance.unlockTime] = scheduledUnlock[lockedBalance.unlockTime].sub(
            lockedBalance.amount);
        scheduledUnlock[unlockTime] = scheduledUnlock[unlockTime].add(lockedBalance.amount);
        locked[msg.sender].unlockTime = unlockTime;

        emit UnlockTimeIncreased(msg.sender, unlockTime);
    }

    function withdraw() external nonReentrant {
        LockedBalance memory lockedBalance = locked[msg.sender];
        require(block.timestamp >= lockedBalance.unlockTime, "The lock is not expired");
        uint256 amount = uint256(lockedBalance.amount);

        lockedBalance.unlockTime = 0;
        lockedBalance.amount = 0;
        locked[msg.sender] = lockedBalance;

        IERC20Upgradeable(token).safeTransfer(msg.sender, amount);

        emit Withdrawn(msg.sender, amount);
    }

    function updateAddressWhitelist(address newWhitelist) external onlyOwner {
        require(
            newWhitelist == address(0) || AddressUpgradeable.isContract(newWhitelist),
            "Smart contract whitelist has to be null or a contract"
        );
        addressWhitelist = newWhitelist;
    }

    function _assertNotContract() private view {
        if (msg.sender != tx.origin) {
            if (
                addressWhitelist != address(0) &&
                IAddressWhitelist(addressWhitelist).check(msg.sender)
            ) {
                return;
            }
            revert("Smart contract depositors not allowed");
        }
    }

    function _balanceOfAtTimestamp(address account, uint256 timestamp)
        private
        view
        returns (uint256)
    {
        require(timestamp >= block.timestamp, "Must be current or future time");
        LockedBalance memory lockedBalance = locked[account];
        if (timestamp > lockedBalance.unlockTime) {
            return 0;
        }
        return lockedBalance.amount.mul(lockedBalance.unlockTime.sub(timestamp))
                                .div(maxTime).mul(releaseRate).div(1e9);
    }

    function _totalSupplyAtTimestamp(uint256 timestamp) private view returns (uint256) {
        uint256 weekCursor = _endOfPeriod(timestamp);
        uint256 total = 0;
        for (; weekCursor <= timestamp + maxTime; weekCursor += periodUnit) {
            total = total.add(
                scheduledUnlock[weekCursor].mul(weekCursor.sub(timestamp))
                .div(maxTime).mul(releaseRate).div(1e9));
        }
        return total;
    }

    function updateMaxTimeAllowed(uint256 newMaxTimeAllowed) external onlyOwner {
        require(newMaxTimeAllowed <= maxTime, "Cannot exceed max time");
        require(newMaxTimeAllowed > maxTimeAllowed, "Cannot shorten max time allowed");
        maxTimeAllowed = newMaxTimeAllowed;
    }

    function updatePeriodUnit(uint256 newPeriodUnit) external onlyOwner {
        periodUnit = newPeriodUnit;
    }

    /// @dev Return end timestamp of the trading week containing a given timestamp.
    ///
    ///      A trading week starts at UTC time `SETTLEMENT_TIME` on a Thursday (inclusive)
    ///      and ends at the same time of the next Thursday (exclusive).
    /// @param timestamp The given timestamp
    /// @return End timestamp of the trading week.
    function _endOfPeriod(uint256 timestamp) public view returns (uint256) {
        return timestamp.add(periodUnit)
                .sub(SETTLEMENT_TIME_RATE.mul(periodUnit).div(1e9))
                .div(periodUnit).mul(periodUnit)
                .add(SETTLEMENT_TIME_RATE.mul(periodUnit).div(1e9));
    }
}
