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
 * @title StakingRewards
 * @dev DeFi Staking & Rewards Protocol with multiple pools, lock periods, and penalties
 */
contract StakingRewards {
    // ============ Types ============
    struct StakingPool {
        uint256 rewardRate; // Rewards per second (in wei)
        uint256 lockPeriod; // Lock period in seconds
        uint256 earlyWithdrawalPenalty; // Penalty percentage (e.g., 10 = 10%)
        bool active;
    }

    struct UserStake {
        uint256 amount;
        uint256 startTime;
        uint256 lastRewardUpdate;
        uint256 accruedRewards;
        uint256 poolId;
    }

    // ============ State Variables ============
    IERC20 public stakingToken;
    address public owner;
    uint256 public poolCount = 0;

    mapping(uint256 => StakingPool) public pools;
    mapping(address => UserStake[]) public userStakes;
    mapping(address => uint256) public totalStaked;

    uint256 public totalRewardsDistributed = 0;
    bool public emergencyWithdrawEnabled = false;

    // ============ Events ============
    event Staked(address indexed user, uint256 amount, uint256 poolId);
    event Withdrawn(address indexed user, uint256 amount, uint256 poolId, uint256 penalty);
    event RewardsClaimed(address indexed user, uint256 amount);
    event PoolCreated(uint256 indexed poolId, uint256 rewardRate, uint256 lockPeriod, uint256 penalty);
    event RewardRateUpdated(uint256 indexed poolId, uint256 newRate);
    event EmergencyWithdraw(address indexed user, uint256 amount);
    event PoolDeactivated(uint256 indexed poolId);

    // ============ Modifiers ============
    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner");
        _;
    }

    // ============ Constructor ============
    constructor(address _stakingToken) {
        require(_stakingToken != address(0), "Invalid token address");
        stakingToken = IERC20(_stakingToken);
        owner = msg.sender;
    }

    // ============ Pool Management ============
    /**
     * @dev Create a new staking pool
     * @param _rewardRate Rewards per second in wei
     * @param _lockPeriod Lock period in seconds
     * @param _earlyWithdrawalPenalty Penalty percentage for early withdrawal
     */
    function createPool(
        uint256 _rewardRate,
        uint256 _lockPeriod,
        uint256 _earlyWithdrawalPenalty
    ) external onlyOwner returns (uint256) {
        require(_rewardRate > 0, "Reward rate must be > 0");
        require(_earlyWithdrawalPenalty <= 100, "Penalty cannot exceed 100%");

        uint256 poolId = poolCount;
        pools[poolId] = StakingPool({
            rewardRate: _rewardRate,
            lockPeriod: _lockPeriod,
            earlyWithdrawalPenalty: _earlyWithdrawalPenalty,
            active: true
        });

        poolCount++;
        emit PoolCreated(poolId, _rewardRate, _lockPeriod, _earlyWithdrawalPenalty);
        return poolId;
    }

    /**
     * @dev Update reward rate for a pool
     * @param _poolId Pool ID
     * @param _newRate New reward rate per second
     */
    function updateRewardRate(uint256 _poolId, uint256 _newRate) external onlyOwner {
        require(pools[_poolId].active, "Pool is inactive");
        require(_newRate > 0, "Reward rate must be > 0");
        pools[_poolId].rewardRate = _newRate;
        emit RewardRateUpdated(_poolId, _newRate);
    }

    /**
     * @dev Deactivate a pool
     * @param _poolId Pool ID
     */
    function deactivatePool(uint256 _poolId) external onlyOwner {
        require(pools[_poolId].active, "Pool is already inactive");
        pools[_poolId].active = false;
        emit PoolDeactivated(_poolId);
    }

    // ============ Staking Functions ============
    /**
     * @dev Stake tokens in a specific pool
     * @param _amount Amount of tokens to stake
     * @param _poolId Pool ID to stake in
     */
    function stake(uint256 _amount, uint256 _poolId) external {
        require(_amount > 0, "Amount must be > 0");
        require(_poolId < poolCount, "Pool does not exist");
        require(pools[_poolId].active, "Pool is inactive");

        // Transfer tokens from user to contract
        require(
            stakingToken.transferFrom(msg.sender, address(this), _amount),
            "Transfer failed"
        );

        // Create new stake
        UserStake memory newStake = UserStake({
            amount: _amount,
            startTime: block.timestamp,
            lastRewardUpdate: block.timestamp,
            accruedRewards: 0,
            poolId: _poolId
        });

        userStakes[msg.sender].push(newStake);
        totalStaked[msg.sender] += _amount;

        emit Staked(msg.sender, _amount, _poolId);
    }

    // ============ Reward Calculation ============
    /**
     * @dev Calculate pending rewards for a user's stake
     * @param _user User address
     * @param _stakeIndex Index of the stake
     */
    function getPendingRewards(address _user, uint256 _stakeIndex) 
        public 
        view 
        returns (uint256) 
    {
        require(_stakeIndex < userStakes[_user].length, "Invalid stake index");

        UserStake memory userStakeInfo = userStakes[_user][_stakeIndex];
        StakingPool memory pool = pools[userStakeInfo.poolId];

        if (!pool.active || userStakeInfo.amount == 0) {
            return userStakeInfo.accruedRewards;
        }

        uint256 timeElapsed = block.timestamp - userStakeInfo.lastRewardUpdate;
        uint256 rewardAccrual = (userStakeInfo.amount * pool.rewardRate * timeElapsed) / 1e18;

        return userStakeInfo.accruedRewards + rewardAccrual;
    }

    /**
     * @dev Get total pending rewards for all user stakes
     * @param _user User address
     */
    function getTotalPendingRewards(address _user) 
        public 
        view 
        returns (uint256) 
    {
        uint256 totalRewards = 0;
        for (uint256 i = 0; i < userStakes[_user].length; i++) {
            totalRewards += getPendingRewards(_user, i);
        }
        return totalRewards;
    }

    // ============ Reward Claiming ============
    /**
     * @dev Update rewards for a specific stake
     * @param _user User address
     * @param _stakeIndex Stake index
     */
    function _updateRewards(address _user, uint256 _stakeIndex) internal {
        require(_stakeIndex < userStakes[_user].length, "Invalid stake index");

        UserStake storage userStakeInfo = userStakes[_user][_stakeIndex];

        if (userStakeInfo.amount == 0) return;

        uint256 pendingRewards = getPendingRewards(_user, _stakeIndex);
        userStakeInfo.accruedRewards = pendingRewards;
        userStakeInfo.lastRewardUpdate = block.timestamp;
    }

    /**
     * @dev Claim rewards from a specific stake
     * @param _stakeIndex Index of the stake
     */
    function claimRewards(uint256 _stakeIndex) external {
        require(_stakeIndex < userStakes[msg.sender].length, "Invalid stake index");

        _updateRewards(msg.sender, _stakeIndex);

        UserStake storage userStakeInfo = userStakes[msg.sender][_stakeIndex];
        uint256 rewards = userStakeInfo.accruedRewards;

        require(rewards > 0, "No rewards to claim");

        userStakeInfo.accruedRewards = 0;
        totalRewardsDistributed += rewards;

        require(stakingToken.transfer(msg.sender, rewards), "Reward transfer failed");

        emit RewardsClaimed(msg.sender, rewards);
    }

    /**
     * @dev Claim all rewards across all stakes
     */
    function claimAllRewards() external {
        uint256 totalRewards = 0;

        for (uint256 i = 0; i < userStakes[msg.sender].length; i++) {
            _updateRewards(msg.sender, i);
            totalRewards += userStakes[msg.sender][i].accruedRewards;
            userStakes[msg.sender][i].accruedRewards = 0;
        }

        require(totalRewards > 0, "No rewards to claim");

        totalRewardsDistributed += totalRewards;
        require(stakingToken.transfer(msg.sender, totalRewards), "Reward transfer failed");

        emit RewardsClaimed(msg.sender, totalRewards);
    }

    // ============ Withdrawal Functions ============
    /**
     * @dev Withdraw stake with early withdrawal penalty if applicable
     * @param _stakeIndex Index of the stake
     */
    function withdraw(uint256 _stakeIndex) external {
        require(_stakeIndex < userStakes[msg.sender].length, "Invalid stake index");

        UserStake storage userStakeInfo = userStakes[msg.sender][_stakeIndex];
        require(userStakeInfo.amount > 0, "No stake to withdraw");

        // Update rewards before withdrawal
        _updateRewards(msg.sender, _stakeIndex);

        StakingPool memory pool = pools[userStakeInfo.poolId];
        uint256 stakeAmount = userStakeInfo.amount;
        uint256 reward = userStakeInfo.accruedRewards;

        // Calculate penalty if lock period not met
        uint256 penalty = 0;
        uint256 timeLocked = block.timestamp - userStakeInfo.startTime;

        if (timeLocked < pool.lockPeriod) {
            penalty = (stakeAmount * pool.earlyWithdrawalPenalty) / 100;
        }

        uint256 amountToTransfer = stakeAmount - penalty + reward;

        // Reset stake
        userStakeInfo.amount = 0;
        userStakeInfo.accruedRewards = 0;
        totalStaked[msg.sender] -= stakeAmount;

        // Transfer tokens back
        require(stakingToken.transfer(msg.sender, amountToTransfer), "Withdrawal transfer failed");

        emit Withdrawn(msg.sender, stakeAmount, userStakeInfo.poolId, penalty);
    }

    /**
     * @dev Emergency withdrawal without rewards (only when enabled by owner)
     * @param _stakeIndex Index of the stake
     */
    function emergencyWithdraw(uint256 _stakeIndex) external {
        require(emergencyWithdrawEnabled, "Emergency withdrawal disabled");
        require(_stakeIndex < userStakes[msg.sender].length, "Invalid stake index");

        UserStake storage userStakeInfo = userStakes[msg.sender][_stakeIndex];
        require(userStakeInfo.amount > 0, "No stake to withdraw");

        uint256 stakeAmount = userStakeInfo.amount;
        userStakeInfo.amount = 0;
        userStakeInfo.accruedRewards = 0;
        totalStaked[msg.sender] -= stakeAmount;

        require(stakingToken.transfer(msg.sender, stakeAmount), "Emergency withdrawal failed");

        emit EmergencyWithdraw(msg.sender, stakeAmount);
    }

    // ============ Admin Functions ============
    /**
     * @dev Enable emergency withdrawal
     */
    function enableEmergencyWithdraw() external onlyOwner {
        emergencyWithdrawEnabled = true;
    }

    /**
     * @dev Disable emergency withdrawal
     */
    function disableEmergencyWithdraw() external onlyOwner {
        emergencyWithdrawEnabled = false;
    }

    /**
     * @dev Recover tokens accidentally sent to contract
     * @param _token Token address
     * @param _amount Amount to recover
     */
    function recoverTokens(address _token, uint256 _amount) external onlyOwner {
        require(_token != address(stakingToken), "Cannot recover staking token");
        require(IERC20(_token).transfer(msg.sender, _amount), "Recovery failed");
    }

    // ============ View Functions ============
    /**
     * @dev Get total number of stakes for a user
     * @param _user User address
     */
    function getUserStakeCount(address _user) external view returns (uint256) {
        return userStakes[_user].length;
    }

    /**
     * @dev Get user stake details
     * @param _user User address
     * @param _stakeIndex Stake index
     */
    function getUserStakeDetails(address _user, uint256 _stakeIndex)
        external
        view
        returns (
            uint256 amount,
            uint256 startTime,
            uint256 accruedRewards,
            uint256 poolId,
            uint256 pendingRewards
        )
    {
        require(_stakeIndex < userStakes[_user].length, "Invalid stake index");
        UserStake memory userStakeInfo = userStakes[_user][_stakeIndex];
        return (
            userStakeInfo.amount,
            userStakeInfo.startTime,
            userStakeInfo.accruedRewards,
            userStakeInfo.poolId,
            getPendingRewards(_user, _stakeIndex)
        );
    }

    /**
     * @dev Get pool details
     * @param _poolId Pool ID
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
        require(_poolId < poolCount, "Pool does not exist");
        StakingPool memory pool = pools[_poolId];
        return (pool.rewardRate, pool.lockPeriod, pool.earlyWithdrawalPenalty, pool.active);
    }
}
