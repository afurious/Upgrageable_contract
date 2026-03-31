// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

interface IERC20 {
    function transfer(address _to, uint256 _value) external returns (bool success);
    function transferFrom(address _from, address _to, uint256 _value) external returns (bool success);
    function balanceOf(address _owner) external view returns (uint256 balance);
    function approve(address _spender, uint256 _value) external returns (bool success);
    function allowance(address _owner, address _spender) external view returns (uint256 remaining);
}

/**
 * @title LibStakingStorage
 * @dev Storage library for Diamond Pattern - maintains storage layout across upgrades
 */
library LibStakingStorage {
    // ============ Types ============
    struct StakingPool {
        uint256 rewardRate;
        uint256 lockPeriod;
        uint256 earlyWithdrawalPenalty;
        bool active;
    }

    struct UserStake {
        uint256 amount;
        uint256 startTime;
        uint256 lastRewardUpdate;
        uint256 accruedRewards;
        uint256 poolId;
    }

    // ============ Storage Position ============
    bytes32 constant STAKING_STORAGE_POSITION = keccak256("staking.storage");

    struct StakingStorage {
        IERC20 stakingToken;
        address owner;
        uint256 poolCount;
        mapping(uint256 => StakingPool) pools;
        mapping(address => UserStake[]) userStakes;
        mapping(address => uint256) totalStaked;
        uint256 totalRewardsDistributed;
        bool emergencyWithdrawEnabled;
    }

    // ============ Getters & Setters ============
    function stakingStorage() internal pure returns (StakingStorage storage ds) {
        bytes32 position = STAKING_STORAGE_POSITION;
        assembly {
            ds.slot := position
        }
    }

    function getOwner() internal view returns (address) {
        return stakingStorage().owner;
    }

    function setOwner(address _owner) internal {
        stakingStorage().owner = _owner;
    }

    function getStakingToken() internal view returns (IERC20) {
        return stakingStorage().stakingToken;
    }

    function setStakingToken(IERC20 _token) internal {
        stakingStorage().stakingToken = _token;
    }
}
