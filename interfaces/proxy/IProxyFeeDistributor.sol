// SPDX-License-Identifier: MIT
pragma solidity >=0.6.10 <0.8.0;

interface IProxyFeeDistributor {
    function owner() external view returns (address);

    function MAX_ADMIN_FEE_RATE() external view returns (uint256);
    function rewardToken() external view returns (address);
    function votingEscrow() external view returns (address);
    function admin() external view returns (address);
    function adminFeeRate() external view returns (uint256);
    function checkpointTimestamp() external view returns (uint256);
    function nextWeekLocked() external view returns (uint256);
    function nextWeekSupply() external view returns (uint256);
    function lastRewardBalance() external view returns (uint256);
    function _endOfPeriod(uint256 timestamp) external view returns (uint256);

    function scheduledUnlock(uint256 timestamp)
        external view returns (uint256);
    function rewardsPerWeek(uint256 timestamp)
        external view returns (uint256);
    function veSupplyPerWeek(uint256 timestamp)
        external view returns (uint256);

    function userLockedBalances(address account)
        external view returns (uint256,uint256);

    function userWeekCursors(address account)
        external view returns (uint256);
    function userLastBalances(address account)
        external view returns (uint256);
    function claimableRewards(address account)
        external view returns (uint256);
    function SETTLEMENT_TIME_RATE() external view returns (uint256);
    function periodUnit() external view returns (uint256);

    event Synchronized(
        address indexed account,
        uint256 oldAmount,
        uint256 oldUnlockTime,
        uint256 newAmount,
        uint256 newUnlockTime
    );

    function balanceOf(address account) external view returns (uint256);

    function totalSupply() external view returns (uint256);

    function balanceOfAtTimestamp(address account, uint256 timestamp)
        external view returns (uint256);

    function totalSupplyAtTimestamp(uint256 timestamp) external view returns (uint256);

    function syncWithVotingEscrow(address account) external;

    function userCheckpoint(address account) external view returns (uint256 rewards);

    function claimRewards(address account) external returns (uint256 rewards);

    function checkpoint() external;
    function updateAdmin(address newAdmin) external;
    function updateAdminFeeRate(uint256 newAdminFeeRate) external;
    function calibrateSupply() external;
}
