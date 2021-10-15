// SPDX-License-Identifier: MIT
pragma solidity >=0.6.10 <0.8.0;
pragma experimental ABIEncoderV2;

interface IFeeDistributor {
    function totalSupply() external view returns (uint256);
    function syncWithVotingEscrow(address account) external;
    function claimRewards(address account) external returns (uint256 rewards);
    function checkpoint() external;
    function _endOfPeriod(uint256 timestamp) external view returns (uint256);
}
