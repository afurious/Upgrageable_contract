// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "../libraries/LibStakingStorage.sol";

/**
 * @title ViewFacet
 * @dev Facet for view functions
 */
contract ViewFacet {
    /**
     * @dev Get user stake details
     */
    function getUserStakeDetails(address _user, uint256 _stakeIndex)
        external
        view
        returns (
            uint256 amount,
            uint256 startTime,
            uint256 accruedRewards,
            uint256 poolId,
            uint256 lockTimeRemaining
        )
    {
        LibStakingStorage.StakingStorage storage ds = LibStakingStorage.stakingStorage();
        require(_stakeIndex < ds.userStakes[_user].length, "Invalid stake index");
        
        LibStakingStorage.UserStake memory userStakeInfo = ds.userStakes[_user][_stakeIndex];
        LibStakingStorage.StakingPool memory pool = ds.pools[userStakeInfo.poolId];
        
        uint256 timeLocked = block.timestamp - userStakeInfo.startTime;
        uint256 remaining = timeLocked < pool.lockPeriod ? pool.lockPeriod - timeLocked : 0;
        
        return (
            userStakeInfo.amount,
            userStakeInfo.startTime,
            userStakeInfo.accruedRewards,
            userStakeInfo.poolId,
            remaining
        );
    }

    /**
     * @dev Get pool count
     */
    function getPoolCount() external view returns (uint256) {
        return LibStakingStorage.stakingStorage().poolCount;
    }

    /**
     * @dev Check if emergency withdrawal is enabled
     */
    function isEmergencyWithdrawEnabled() external view returns (bool) {
        return LibStakingStorage.stakingStorage().emergencyWithdrawEnabled;
    }
}
