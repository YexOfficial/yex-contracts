// SPDX-License-Identifier: MIT
pragma solidity >=0.6.10 <0.8.0;


interface IProxyVotingEscrow {
    function owner() external view returns (address);

    event LockCreated(address indexed account, uint256 amount, uint256 unlockTime);
    event AmountIncreased(address indexed account, uint256 increasedAmount);
    event UnlockTimeIncreased(address indexed account, uint256 newUnlockTime);
    event Withdrawn(address indexed account, uint256 amount);

    function token() external view returns (address);
    function symbol() external view returns (address);
    function addressWhitelist() external view returns (address);
    function maxTime() external view returns (uint256);
    function maxTimeAllowed() external view returns (uint256);
    function SETTLEMENT_TIME_RATE() external view returns (uint256);
    function periodUnit() external view returns (uint256);

    function balanceOf(address account) external view returns (uint256);
    function totalSupply() external view returns (uint256);

    function balanceOfAtTimestamp(address account, uint256 timestamp)
        external view returns (uint256);
    function totalSupplyAtTimestamp(uint256 timestamp)
        external view returns (uint256);

    function getTimestampDropBelow(address account, uint256 threshold)
        external view returns (uint256);

    function locked(address account) external view returns (address, uint256 timestamp);
    function scheduledUnlock(uint256 value) external view returns (uint256 timestamp);

    function getLockedBalance(address account)
        external view returns (address, uint256 timestamp);


    function createLock(
        uint256 amount,
        uint256 unlockTime,
        address,
        bytes memory
    ) external;
    
    function increaseAmount(
        address account,
        uint256 amount,
        address,
        bytes memory
    ) external;

    function increaseUnlockTime(
        uint256 unlockTime,
        address,
        bytes memory
    ) external;

    function withdraw() external;
    function updateAddressWhitelist(address newWhitelist) external;
    function updateMaxTimeAllowed(uint256 newMaxTimeAllowed) external;
    function updatePeriodUnit(uint256 newPeriodUnit) external;

    function _endOfPeriod(uint256 timestamp) external view returns (uint256);
}
