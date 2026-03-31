// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "forge-std/Test.sol";
import "../src/Diamond.sol";
import "../src/facets/DiamondCutFacet.sol";
import "../src/facets/DiamondLoupeFacet.sol";
import "../src/facets/PoolManagementFacet.sol";
import "../src/facets/StakingFacet.sol";
import "../src/facets/RewardsFacet.sol";
import "../src/facets/WithdrawalFacet.sol";
import "../src/facets/AdminFacet.sol";
import "../src/facets/ViewFacet.sol";
import "../src/interfaces/IDiamondCut.sol";
import "./mocks/MockERC20.sol";

contract DiamondInitTest is Test {
    Diamond diamond;
    MockERC20 token;
    
    DiamondCutFacet diamondCutFacet;
    DiamondLoupeFacet diamondLoupeFacet;
    PoolManagementFacet poolManagementFacet;
    StakingFacet stakingFacet;
    RewardsFacet rewardsFacet;
    WithdrawalFacet withdrawalFacet;
    AdminFacet adminFacet;
    ViewFacet viewFacet;

    address owner = address(0x1);
    address user1 = address(0x2);
    address user2 = address(0x3);

    function setUp() public {
        vm.startPrank(owner);

        // Deploy mock token
        token = new MockERC20("Staking Token", "STK", 18);

        // Deploy facets
        diamondCutFacet = new DiamondCutFacet();
        diamondLoupeFacet = new DiamondLoupeFacet();
        poolManagementFacet = new PoolManagementFacet();
        stakingFacet = new StakingFacet();
        rewardsFacet = new RewardsFacet();
        withdrawalFacet = new WithdrawalFacet();
        adminFacet = new AdminFacet();
        viewFacet = new ViewFacet();

        // Deploy Diamond
        diamond = new Diamond(owner, address(token), address(diamondCutFacet));

        // Add all facets
        IDiamondCut.FacetCut[] memory cuts = new IDiamondCut.FacetCut[](7);

        // DiamondLoupe
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

        // PoolManagement
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

        // Staking
        bytes4[] memory stakingSelectors = new bytes4[](2);
        stakingSelectors[0] = StakingFacet.stake.selector;
        stakingSelectors[1] = StakingFacet.getUserStakeCount.selector;

        cuts[2] = IDiamondCut.FacetCut({
            facetAddress: address(stakingFacet),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: stakingSelectors
        });

        // Rewards
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

        // Withdrawal
        bytes4[] memory withdrawalSelectors = new bytes4[](2);
        withdrawalSelectors[0] = WithdrawalFacet.withdraw.selector;
        withdrawalSelectors[1] = WithdrawalFacet.emergencyWithdraw.selector;

        cuts[4] = IDiamondCut.FacetCut({
            facetAddress: address(withdrawalFacet),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: withdrawalSelectors
        });

        // Admin
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

        // View
        bytes4[] memory viewSelectors = new bytes4[](3);
        viewSelectors[0] = ViewFacet.getUserStakeDetails.selector;
        viewSelectors[1] = ViewFacet.getPoolCount.selector;
        viewSelectors[2] = ViewFacet.isEmergencyWithdrawEnabled.selector;

        cuts[6] = IDiamondCut.FacetCut({
            facetAddress: address(viewFacet),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: viewSelectors
        });

        IDiamondCut(address(diamond)).diamondCut(cuts, address(0), "");

        vm.stopPrank();

        // Mint tokens to users
        token.mint(user1, 1000 ether);
        token.mint(user2, 1000 ether);
        token.mint(owner, 1000 ether);
    }

    function test_DiamondInitialization() public {
        // Check owner is set correctly
        assertEq(AdminFacet(address(diamond)).getOwner(), owner);
        
        // Check token is set correctly
        assertEq(AdminFacet(address(diamond)).getStakingToken(), address(token));
        
        // Check pool count is 0
        assertEq(ViewFacet(address(diamond)).getPoolCount(), 0);
    }

    function test_DiamondCanRoute() public {
        // Verify all facets are properly routed
        assertTrue(DiamondLoupeFacet(address(diamond)).facetAddress(PoolManagementFacet.createPool.selector) != address(0));
        assertTrue(DiamondLoupeFacet(address(diamond)).facetAddress(StakingFacet.stake.selector) != address(0));
        assertTrue(DiamondLoupeFacet(address(diamond)).facetAddress(RewardsFacet.getPendingRewards.selector) != address(0));
    }
}
