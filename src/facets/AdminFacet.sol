// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "../libraries/LibStakingStorage.sol";

/**
 * @title AdminFacet
 * @dev Facet for admin operations
 */
contract AdminFacet {
    modifier onlyOwner() {
        require(msg.sender == LibStakingStorage.getOwner(), "Only owner");
        _;
    }

    /**
     * @dev Enable emergency withdrawal
     */
    function enableEmergencyWithdraw() external onlyOwner {
        LibStakingStorage.stakingStorage().emergencyWithdrawEnabled = true;
    }

    /**
     * @dev Disable emergency withdrawal
     */
    function disableEmergencyWithdraw() external onlyOwner {
        LibStakingStorage.stakingStorage().emergencyWithdrawEnabled = false;
    }

    /**
     * @dev Recover tokens accidentally sent to contract
     */
    function recoverTokens(address _token, uint256 _amount) external onlyOwner {
        LibStakingStorage.StakingStorage storage ds = LibStakingStorage.stakingStorage();
        require(_token != address(ds.stakingToken), "Cannot recover staking token");
        require(IERC20(_token).transfer(msg.sender, _amount), "Recovery failed");
    }

    /**
     * @dev Transfer ownership to a new address
     */
    function transferOwnership(address _newOwner) external onlyOwner {
        require(_newOwner != address(0), "Invalid new owner");
        LibStakingStorage.setOwner(_newOwner);
    }

    /**
     * @dev Get current owner
     */
    function getOwner() external view returns (address) {
        return LibStakingStorage.getOwner();
    }

    /**
     * @dev Get staking token address
     */
    function getStakingToken() external view returns (address) {
        return address(LibStakingStorage.getStakingToken());
    }

    /**
     * @dev Get total rewards distributed
     */
    function getTotalRewardsDistributed() external view returns (uint256) {
        return LibStakingStorage.stakingStorage().totalRewardsDistributed;
    }

    /**
     * @dev Get user total staked amount
     */
    function getUserTotalStaked(address _user) external view returns (uint256) {
        return LibStakingStorage.stakingStorage().totalStaked[_user];
    }
}
