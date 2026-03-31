// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "../libraries/LibStakingStorage.sol";

/**
 * @title WithdrawalFacet
 * @dev Facet for withdrawal operations
 */
contract WithdrawalFacet {
    event Withdrawn(address indexed user, uint256 amount, uint256 poolId, uint256 penalty);
    event EmergencyWithdraw(address indexed user, uint256 amount);

    /**
     * @dev Internal function to update rewards (imported from RewardsFacet logic)
     */
    function _getPendingRewards(address _user, uint256 _stakeIndex) 
        internal 
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
     * @dev Internal function to update rewards
     */
    function _updateRewards(address _user, uint256 _stakeIndex) internal {
        LibStakingStorage.StakingStorage storage ds = LibStakingStorage.stakingStorage();
        require(_stakeIndex < ds.userStakes[_user].length, "Invalid stake index");

        LibStakingStorage.UserStake storage userStakeInfo = ds.userStakes[_user][_stakeIndex];

        if (userStakeInfo.amount == 0) return;

        uint256 pendingRewards = _getPendingRewards(_user, _stakeIndex);
        userStakeInfo.accruedRewards = pendingRewards;
        userStakeInfo.lastRewardUpdate = block.timestamp;
    }

    /**
     * @dev Withdraw stake with early withdrawal penalty if applicable
     */
    function withdraw(uint256 _stakeIndex) external {
        LibStakingStorage.StakingStorage storage ds = LibStakingStorage.stakingStorage();
        require(_stakeIndex < ds.userStakes[msg.sender].length, "Invalid stake index");

        LibStakingStorage.UserStake storage userStakeInfo = ds.userStakes[msg.sender][_stakeIndex];
        require(userStakeInfo.amount > 0, "No stake to withdraw");

        _updateRewards(msg.sender, _stakeIndex);

        LibStakingStorage.StakingPool memory pool = ds.pools[userStakeInfo.poolId];
        uint256 stakeAmount = userStakeInfo.amount;
        uint256 reward = userStakeInfo.accruedRewards;

        uint256 penalty = 0;
        uint256 timeLocked = block.timestamp - userStakeInfo.startTime;

        if (timeLocked < pool.lockPeriod) {
            penalty = (stakeAmount * pool.earlyWithdrawalPenalty) / 100;
        }

        uint256 amountToTransfer = stakeAmount - penalty + reward;

        userStakeInfo.amount = 0;
        userStakeInfo.accruedRewards = 0;
        ds.totalStaked[msg.sender] -= stakeAmount;

        require(ds.stakingToken.transfer(msg.sender, amountToTransfer), "Withdrawal transfer failed");

        emit Withdrawn(msg.sender, stakeAmount, userStakeInfo.poolId, penalty);
    }

    /**
     * @dev Emergency withdrawal without rewards (only when enabled by owner)
     */
    function emergencyWithdraw(uint256 _stakeIndex) external {
        LibStakingStorage.StakingStorage storage ds = LibStakingStorage.stakingStorage();
        require(ds.emergencyWithdrawEnabled, "Emergency withdrawal disabled");
        require(_stakeIndex < ds.userStakes[msg.sender].length, "Invalid stake index");

        LibStakingStorage.UserStake storage userStakeInfo = ds.userStakes[msg.sender][_stakeIndex];
        require(userStakeInfo.amount > 0, "No stake to withdraw");

        uint256 stakeAmount = userStakeInfo.amount;
        userStakeInfo.amount = 0;
        userStakeInfo.accruedRewards = 0;
        ds.totalStaked[msg.sender] -= stakeAmount;

        require(ds.stakingToken.transfer(msg.sender, stakeAmount), "Emergency withdrawal failed");

        emit EmergencyWithdraw(msg.sender, stakeAmount);
    }
}
