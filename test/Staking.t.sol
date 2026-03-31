// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "forge-std/Test.sol";
import "../src/Diamond.sol";
import "../src/facets/DiamondCutFacet.sol";
import "../src/facets/DiamondLoupeFacet.sol";
import "../src/facets/PoolManagementFacet.sol";
import "../src/facets/StakingFacet.sol";
import "../src/facets/RewardsFacet.sol";
import "../src/facets/ViewFacet.sol";
import "../src/facets/AdminFacet.sol";
import "../src/interfaces/IDiamondCut.sol";
import "./mocks/MockERC20.sol";

contract StakingTest is Test {
    Diamond diamond;
    MockERC20 token;
    
    address owner = address(0x1);
    address user1 = address(0x2);
    address user2 = address(0x3);
    
    uint256 constant REWARD_RATE = 1e17; // 0.1 tokens per second
    uint256 constant LOCK_PERIOD = 7 days;
    uint256 constant PENALTY = 10; // 10%

    function setUp() public {
        vm.startPrank(owner);

        // Deploy and setup diamond
        token = new MockERC20("Staking Token", "STK", 18);
        
        DiamondCutFacet diamondCutFacet = new DiamondCutFacet();
        diamond = new Diamond(owner, address(token), address(diamondCutFacet));

        // Setup all facets (simplified - just the ones we need for this test)
        DiamondLoupeFacet diamondLoupeFacet = new DiamondLoupeFacet();
        PoolManagementFacet poolManagementFacet = new PoolManagementFacet();
        StakingFacet stakingFacet = new StakingFacet();
        RewardsFacet rewardsFacet = new RewardsFacet();
        ViewFacet viewFacet = new ViewFacet();
        AdminFacet adminFacet = new AdminFacet();

        IDiamondCut.FacetCut[] memory cuts = new IDiamondCut.FacetCut[](6);

        bytes4[] memory diamondLoupeSelectors = new bytes4[](5);
        diamondLoupeSelectors[0] = DiamondLoupeFacet.facets.selector;
        diamondLoupeSelectors[1] = DiamondLoupeFacet.facetFunctionSelectors.selector;
        diamondLoupeSelectors[2] = DiamondLoupeFacet.facetAddresses.selector;
        diamondLoupeSelectors[3] = DiamondLoupeFacet.facetAddress.selector;
        diamondLoupeSelectors[4] = DiamondLoupeFacet.supportsInterface.selector;

        cuts[0] = IDiamondCut.FacetCut({
            facetAddress: address(diamondLoupeFacet),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: diamondLoupeSelectors
        });

        bytes4[] memory poolMgmtSelectors = new bytes4[](4);
        poolMgmtSelectors[0] = PoolManagementFacet.createPool.selector;
        poolMgmtSelectors[1] = PoolManagementFacet.updateRewardRate.selector;
        poolMgmtSelectors[2] = PoolManagementFacet.deactivatePool.selector;
        poolMgmtSelectors[3] = PoolManagementFacet.getPoolDetails.selector;

        cuts[1] = IDiamondCut.FacetCut({
            facetAddress: address(poolManagementFacet),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: poolMgmtSelectors
        });

        bytes4[] memory stakingSelectors = new bytes4[](2);
        stakingSelectors[0] = StakingFacet.stake.selector;
        stakingSelectors[1] = StakingFacet.getUserStakeCount.selector;

        cuts[2] = IDiamondCut.FacetCut({
            facetAddress: address(stakingFacet),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: stakingSelectors
        });

        bytes4[] memory rewardsSelectors = new bytes4[](4);
        rewardsSelectors[0] = RewardsFacet.getPendingRewards.selector;
        rewardsSelectors[1] = RewardsFacet.getTotalPendingRewards.selector;
        rewardsSelectors[2] = RewardsFacet.claimRewards.selector;
        rewardsSelectors[3] = RewardsFacet.claimAllRewards.selector;

        cuts[3] = IDiamondCut.FacetCut({
            facetAddress: address(rewardsFacet),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: rewardsSelectors
        });

        bytes4[] memory viewSelectors = new bytes4[](3);
        viewSelectors[0] = ViewFacet.getUserStakeDetails.selector;
        viewSelectors[1] = ViewFacet.getPoolCount.selector;
        viewSelectors[2] = ViewFacet.isEmergencyWithdrawEnabled.selector;

        cuts[4] = IDiamondCut.FacetCut({
            facetAddress: address(viewFacet),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: viewSelectors
        });

        bytes4[] memory adminSelectors = new bytes4[](6);
        adminSelectors[0] = AdminFacet.enableEmergencyWithdraw.selector;
        adminSelectors[1] = AdminFacet.disableEmergencyWithdraw.selector;
        adminSelectors[2] = AdminFacet.recoverTokens.selector;
        adminSelectors[3] = AdminFacet.transferOwnership.selector;
        adminSelectors[4] = AdminFacet.getOwner.selector;
        adminSelectors[5] = AdminFacet.getStakingToken.selector;

        cuts[5] = IDiamondCut.FacetCut({
            facetAddress: address(adminFacet),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: adminSelectors
        });

        IDiamondCut(address(diamond)).diamondCut(cuts, address(0), "");

        vm.stopPrank();

        // Mint tokens
        token.mint(user1, 1000 ether);
        token.mint(user2, 1000 ether);
        token.mint(owner, 1000 ether);
    }

    function test_CreatePool() public {
        vm.prank(owner);
        uint256 poolId = PoolManagementFacet(address(diamond)).createPool(REWARD_RATE, LOCK_PERIOD, PENALTY);
        
        assertEq(poolId, 0);
        assertEq(ViewFacet(address(diamond)).getPoolCount(), 1);
    }

    function test_StakeTokens() public {
        vm.prank(owner);
        PoolManagementFacet(address(diamond)).createPool(REWARD_RATE, LOCK_PERIOD, PENALTY);

        vm.startPrank(user1);
        token.approve(address(diamond), 100 ether);
        StakingFacet(address(diamond)).stake(100 ether, 0);
        vm.stopPrank();

        assertEq(StakingFacet(address(diamond)).getUserStakeCount(user1), 1);
        assertEq(token.balanceOf(address(diamond)), 100 ether);
    }

    function test_StakeFailsWithInactivePool() public {
        vm.startPrank(owner);
        uint256 poolId = PoolManagementFacet(address(diamond)).createPool(REWARD_RATE, LOCK_PERIOD, PENALTY);
        PoolManagementFacet(address(diamond)).deactivatePool(poolId);
        vm.stopPrank();

        vm.startPrank(user1);
        token.approve(address(diamond), 100 ether);
        vm.expectRevert("Pool is inactive");
        StakingFacet(address(diamond)).stake(100 ether, poolId);
        vm.stopPrank();
    }

    function test_AccrueRewards() public {
        vm.prank(owner);
        PoolManagementFacet(address(diamond)).createPool(REWARD_RATE, LOCK_PERIOD, PENALTY);

        vm.startPrank(user1);
        token.approve(address(diamond), 100 ether);
        StakingFacet(address(diamond)).stake(100 ether, 0);
        vm.stopPrank();

        // Fast forward 10 seconds
        vm.warp(block.timestamp + 10);

        uint256 pendingRewards = RewardsFacet(address(diamond)).getPendingRewards(user1, 0);
        
        // REWARD_RATE * amount * time / 1e18 = 1e17 * 100e18 * 10 / 1e18 = 1e17 * 100 * 10 = 1e20
        uint256 expectedRewards = (100 ether * REWARD_RATE * 10) / 1e18;
        assertEq(pendingRewards, expectedRewards);
    }

    function test_ClaimRewards() public {
        vm.prank(owner);
        PoolManagementFacet(address(diamond)).createPool(REWARD_RATE, LOCK_PERIOD, PENALTY);

        vm.startPrank(user1);
        token.approve(address(diamond), 100 ether);
        StakingFacet(address(diamond)).stake(100 ether, 0);
        vm.stopPrank();

        vm.warp(block.timestamp + 10);

        uint256 balanceBefore = token.balanceOf(user1);
        
        vm.prank(user1);
        RewardsFacet(address(diamond)).claimRewards(0);

        uint256 balanceAfter = token.balanceOf(user1);
        uint256 expectedRewards = (100 ether * REWARD_RATE * 10) / 1e18;
        
        assertEq(balanceAfter - balanceBefore, expectedRewards);
    }

    function test_MultipleStakes() public {
        vm.prank(owner);
        PoolManagementFacet(address(diamond)).createPool(REWARD_RATE, LOCK_PERIOD, PENALTY);

        vm.startPrank(user1);
        token.approve(address(diamond), 300 ether);
        StakingFacet(address(diamond)).stake(100 ether, 0);
        StakingFacet(address(diamond)).stake(200 ether, 0);
        vm.stopPrank();

        assertEq(StakingFacet(address(diamond)).getUserStakeCount(user1), 2);
        
        vm.warp(block.timestamp + 10);
        
        uint256 totalRewards = RewardsFacet(address(diamond)).getTotalPendingRewards(user1);
        uint256 stake1Rewards = (100 ether * REWARD_RATE * 10) / 1e18;
        uint256 stake2Rewards = (200 ether * REWARD_RATE * 10) / 1e18;
        
        assertEq(totalRewards, stake1Rewards + stake2Rewards);
    }

    function test_ClaimAllRewards() public {
        vm.prank(owner);
        PoolManagementFacet(address(diamond)).createPool(REWARD_RATE, LOCK_PERIOD, PENALTY);

        vm.startPrank(user1);
        token.approve(address(diamond), 300 ether);
        StakingFacet(address(diamond)).stake(100 ether, 0);
        StakingFacet(address(diamond)).stake(200 ether, 0);
        vm.stopPrank();

        vm.warp(block.timestamp + 10);

        uint256 balanceBefore = token.balanceOf(user1);
        
        vm.prank(user1);
        RewardsFacet(address(diamond)).claimAllRewards();

        uint256 balanceAfter = token.balanceOf(user1);
        uint256 stake1Rewards = (100 ether * REWARD_RATE * 10) / 1e18;
        uint256 stake2Rewards = (200 ether * REWARD_RATE * 10) / 1e18;
        
        assertEq(balanceAfter - balanceBefore, stake1Rewards + stake2Rewards);
    }
}
