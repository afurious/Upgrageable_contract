// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "../libraries/LibStakingStorage.sol";

/**
 * @title StakingFacet
 * @dev Facet for staking operations
 */
contract StakingFacet {
    event Staked(address indexed user, uint256 amount, uint256 poolId);

    /**
     * @dev Stake tokens in a specific pool
     */
    function stake(uint256 _amount, uint256 _poolId) external {
        require(_amount > 0, "Amount must be > 0");
        
        LibStakingStorage.StakingStorage storage ds = LibStakingStorage.stakingStorage();
        require(_poolId < ds.poolCount, "Pool does not exist");
        require(ds.pools[_poolId].active, "Pool is inactive");

        require(
            ds.stakingToken.transferFrom(msg.sender, address(this), _amount),
            "Transfer failed"
        );

        LibStakingStorage.UserStake memory newStake = LibStakingStorage.UserStake({
            amount: _amount,
            startTime: block.timestamp,
            lastRewardUpdate: block.timestamp,
            accruedRewards: 0,
            poolId: _poolId
        });

        ds.userStakes[msg.sender].push(newStake);
        ds.totalStaked[msg.sender] += _amount;

        emit Staked(msg.sender, _amount, _poolId);
    }

    /**
     * @dev Get total number of stakes for a user
     */
    function getUserStakeCount(address _user) external view returns (uint256) {
        return LibStakingStorage.stakingStorage().userStakes[_user].length;
    }
}
