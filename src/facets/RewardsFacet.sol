// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "../libraries/LibStakingStorage.sol";

/**
 * @title RewardsFacet
 * @dev Facet for reward calculations and claiming
 */
contract RewardsFacet {
    event RewardsClaimed(address indexed user, uint256 amount);

    /**
     * @dev Calculate pending rewards for a user's stake
     */
    function getPendingRewards(address _user, uint256 _stakeIndex) 
        public 
        view 
        returns (uint256) 
    {
        LibStakingStorage.StakingStorage storage ds = LibStakingStorage.stakingStorage();
        require(_stakeIndex < ds.userStakes[_user].length, "Invalid stake index");

        LibStakingStorage.UserStake memory userStakeInfo = ds.userStakes[_user][_stakeIndex];
        LibStakingStorage.StakingPool memory pool = ds.pools[userStakeInfo.poolId];

        if (!pool.active || userStakeInfo.amount == 0) {
            return userStakeInfo.accruedRewards;
        }

        uint256 timeElapsed = block.timestamp - userStakeInfo.lastRewardUpdate;
        uint256 rewardAccrual = (userStakeInfo.amount * pool.rewardRate * timeElapsed) / 1e18;

        return userStakeInfo.accruedRewards + rewardAccrual;
    }

    /**
     * @dev Get total pending rewards for all user stakes
     */
    function getTotalPendingRewards(address _user) 
        public 
        view 
        returns (uint256) 
    {
        LibStakingStorage.StakingStorage storage ds = LibStakingStorage.stakingStorage();
        uint256 totalRewards = 0;
        for (uint256 i = 0; i < ds.userStakes[_user].length; i++) {
            totalRewards += getPendingRewards(_user, i);
        }
        return totalRewards;
    }

    /**
     * @dev Internal function to update rewards for a specific stake
     */
    function _updateRewards(address _user, uint256 _stakeIndex) internal {
        LibStakingStorage.StakingStorage storage ds = LibStakingStorage.stakingStorage();
        require(_stakeIndex < ds.userStakes[_user].length, "Invalid stake index");

        LibStakingStorage.UserStake storage userStakeInfo = ds.userStakes[_user][_stakeIndex];

        if (userStakeInfo.amount == 0) return;

        uint256 pendingRewards = getPendingRewards(_user, _stakeIndex);
        userStakeInfo.accruedRewards = pendingRewards;
        userStakeInfo.lastRewardUpdate = block.timestamp;
    }

    /**
     * @dev Claim rewards from a specific stake
     */
    function claimRewards(uint256 _stakeIndex) external {
        LibStakingStorage.StakingStorage storage ds = LibStakingStorage.stakingStorage();
        require(_stakeIndex < ds.userStakes[msg.sender].length, "Invalid stake index");

        _updateRewards(msg.sender, _stakeIndex);

        LibStakingStorage.UserStake storage userStakeInfo = ds.userStakes[msg.sender][_stakeIndex];
        uint256 rewards = userStakeInfo.accruedRewards;

        require(rewards > 0, "No rewards to claim");

        userStakeInfo.accruedRewards = 0;
        ds.totalRewardsDistributed += rewards;

        require(ds.stakingToken.transfer(msg.sender, rewards), "Reward transfer failed");

        emit RewardsClaimed(msg.sender, rewards);
    }

    /**
     * @dev Claim all rewards across all stakes
     */
    function claimAllRewards() external {
        LibStakingStorage.StakingStorage storage ds = LibStakingStorage.stakingStorage();
        uint256 totalRewards = 0;

        for (uint256 i = 0; i < ds.userStakes[msg.sender].length; i++) {
            _updateRewards(msg.sender, i);
            totalRewards += ds.userStakes[msg.sender][i].accruedRewards;
            ds.userStakes[msg.sender][i].accruedRewards = 0;
        }

        require(totalRewards > 0, "No rewards to claim");

        ds.totalRewardsDistributed += totalRewards;
        require(ds.stakingToken.transfer(msg.sender, totalRewards), "Reward transfer failed");

        emit RewardsClaimed(msg.sender, totalRewards);
    }
}
