// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "../libraries/LibStakingStorage.sol";

/**
 * @title PoolManagementFacet
 * @dev Facet for managing staking pools
 */
contract PoolManagementFacet {
    event PoolCreated(uint256 indexed poolId, uint256 rewardRate, uint256 lockPeriod, uint256 penalty);
    event RewardRateUpdated(uint256 indexed poolId, uint256 newRate);
    event PoolDeactivated(uint256 indexed poolId);

    modifier onlyOwner() {
        require(msg.sender == LibStakingStorage.getOwner(), "Only owner");
        _;
    }

    /**
     * @dev Create a new staking pool
     */
    function createPool(
        uint256 _rewardRate,
        uint256 _lockPeriod,
        uint256 _earlyWithdrawalPenalty
    ) external onlyOwner returns (uint256) {
        require(_rewardRate > 0, "Reward rate must be > 0");
        require(_earlyWithdrawalPenalty <= 100, "Penalty cannot exceed 100%");

        LibStakingStorage.StakingStorage storage ds = LibStakingStorage.stakingStorage();
        uint256 poolId = ds.poolCount;

        ds.pools[poolId] = LibStakingStorage.StakingPool({
            rewardRate: _rewardRate,
            lockPeriod: _lockPeriod,
            earlyWithdrawalPenalty: _earlyWithdrawalPenalty,
            active: true
        });

        ds.poolCount++;
        emit PoolCreated(poolId, _rewardRate, _lockPeriod, _earlyWithdrawalPenalty);
        return poolId;
    }

    /**
     * @dev Update reward rate for a pool
     */
    function updateRewardRate(uint256 _poolId, uint256 _newRate) external onlyOwner {
        LibStakingStorage.StakingStorage storage ds = LibStakingStorage.stakingStorage();
        require(ds.pools[_poolId].active, "Pool is inactive");
        require(_newRate > 0, "Reward rate must be > 0");
        ds.pools[_poolId].rewardRate = _newRate;
        emit RewardRateUpdated(_poolId, _newRate);
    }

    /**
     * @dev Deactivate a pool
     */
    function deactivatePool(uint256 _poolId) external onlyOwner {
        LibStakingStorage.StakingStorage storage ds = LibStakingStorage.stakingStorage();
        require(ds.pools[_poolId].active, "Pool is already inactive");
        ds.pools[_poolId].active = false;
        emit PoolDeactivated(_poolId);
    }

    /**
     * @dev Get pool details
     */
    function getPoolDetails(uint256 _poolId)
        external
        view
        returns (
            uint256 rewardRate,
            uint256 lockPeriod,
            uint256 earlyWithdrawalPenalty,
            bool active
        )
    {
        LibStakingStorage.StakingStorage storage ds = LibStakingStorage.stakingStorage();
        require(_poolId < ds.poolCount, "Pool does not exist");
        LibStakingStorage.StakingPool memory pool = ds.pools[_poolId];
        return (pool.rewardRate, pool.lockPeriod, pool.earlyWithdrawalPenalty, pool.active);
    }
}
