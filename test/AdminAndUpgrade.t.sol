// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "forge-std/Test.sol";
import "../src/Diamond.sol";
import "../src/facets/DiamondCutFacet.sol";
import "../src/facets/DiamondLoupeFacet.sol";
import "../src/facets/PoolManagementFacet.sol";
import "../src/facets/AdminFacet.sol";
import "../src/facets/ViewFacet.sol";
import "../src/interfaces/IDiamondCut.sol";
import "./mocks/MockERC20.sol";

contract AdminAndUpgradeTest is Test {
    Diamond diamond;
    MockERC20 token;
    MockERC20 otherToken;
    
    address owner = address(0x1);
    address newOwner = address(0x2);
    address user1 = address(0x3);

    function setUp() public {
        vm.startPrank(owner);

        token = new MockERC20("Staking Token", "STK", 18);
        otherToken = new MockERC20("Other Token", "OTHER", 18);
        
        DiamondCutFacet diamondCutFacet = new DiamondCutFacet();
        diamond = new Diamond(owner, address(token), address(diamondCutFacet));

        DiamondLoupeFacet diamondLoupeFacet = new DiamondLoupeFacet();
        PoolManagementFacet poolManagementFacet = new PoolManagementFacet();
        AdminFacet adminFacet = new AdminFacet();
        ViewFacet viewFacet = new ViewFacet();

        IDiamondCut.FacetCut[] memory cuts = new IDiamondCut.FacetCut[](4);

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

        bytes4[] memory adminSelectors = new bytes4[](6);
        adminSelectors[0] = AdminFacet.enableEmergencyWithdraw.selector;
        adminSelectors[1] = AdminFacet.disableEmergencyWithdraw.selector;
        adminSelectors[2] = AdminFacet.recoverTokens.selector;
        adminSelectors[3] = AdminFacet.transferOwnership.selector;
        adminSelectors[4] = AdminFacet.getOwner.selector;
        adminSelectors[5] = AdminFacet.getStakingToken.selector;

        cuts[2] = IDiamondCut.FacetCut({
            facetAddress: address(adminFacet),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: adminSelectors
        });

        bytes4[] memory viewSelectors = new bytes4[](3);
        viewSelectors[0] = ViewFacet.getUserStakeDetails.selector;
        viewSelectors[1] = ViewFacet.getPoolCount.selector;
        viewSelectors[2] = ViewFacet.isEmergencyWithdrawEnabled.selector;

        cuts[3] = IDiamondCut.FacetCut({
            facetAddress: address(viewFacet),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: viewSelectors
        });

        IDiamondCut(address(diamond)).diamondCut(cuts, address(0), "");

        vm.stopPrank();

        otherToken.mint(address(diamond), 100 ether);
    }

    function test_GetOwner() public {
        assertEq(AdminFacet(address(diamond)).getOwner(), owner);
    }

    function test_GetStakingToken() public {
        assertEq(AdminFacet(address(diamond)).getStakingToken(), address(token));
    }

    function test_TransferOwnership() public {
        vm.prank(owner);
        AdminFacet(address(diamond)).transferOwnership(newOwner);
        
        assertEq(AdminFacet(address(diamond)).getOwner(), newOwner);
    }

    function test_TransferOwnershipUnauthorized() public {
        vm.prank(user1);
        vm.expectRevert("Only owner");
        AdminFacet(address(diamond)).transferOwnership(newOwner);
    }

    function test_EnableEmergencyWithdraw() public {
        vm.prank(owner);
        AdminFacet(address(diamond)).enableEmergencyWithdraw();
        
        assertTrue(ViewFacet(address(diamond)).isEmergencyWithdrawEnabled());
    }

    function test_DisableEmergencyWithdraw() public {
        vm.startPrank(owner);
        AdminFacet(address(diamond)).enableEmergencyWithdraw();
        AdminFacet(address(diamond)).disableEmergencyWithdraw();
        vm.stopPrank();
        
        assertFalse(ViewFacet(address(diamond)).isEmergencyWithdrawEnabled());
    }

    function test_RecoverTokens() public {
        uint256 balanceBefore = otherToken.balanceOf(owner);
        
        vm.prank(owner);
        AdminFacet(address(diamond)).recoverTokens(address(otherToken), 100 ether);
        
        uint256 balanceAfter = otherToken.balanceOf(owner);
        assertEq(balanceAfter - balanceBefore, 100 ether);
    }

    function test_CannotRecoverStakingToken() public {
        vm.prank(owner);
        vm.expectRevert("Cannot recover staking token");
        AdminFacet(address(diamond)).recoverTokens(address(token), 100 ether);
    }

    function test_RecoverTokensUnauthorized() public {
        vm.prank(user1);
        vm.expectRevert("Only owner");
        AdminFacet(address(diamond)).recoverTokens(address(otherToken), 100 ether);
    }

    function test_DiamondCutOnlyOwner() public {
        PoolManagementFacet newFacet = new PoolManagementFacet();
        
        IDiamondCut.FacetCut[] memory cuts = new IDiamondCut.FacetCut[](1);
        bytes4[] memory selectors = new bytes4[](1);
        selectors[0] = bytes4(keccak256("testFunction()"));
        
        cuts[0] = IDiamondCut.FacetCut({
            facetAddress: address(newFacet),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: selectors
        });

        vm.prank(user1);
        vm.expectRevert("Only owner");
        IDiamondCut(address(diamond)).diamondCut(cuts, address(0), "");
    }

    function test_UpdateRewardRateOnlyOwner() public {
        vm.prank(owner);
        PoolManagementFacet(address(diamond)).createPool(1e17, 7 days, 10);

        vm.prank(user1);
        vm.expectRevert("Only owner");
        PoolManagementFacet(address(diamond)).updateRewardRate(0, 2e17);
    }

    function test_CreatePoolOnlyOwner() public {
        vm.prank(user1);
        vm.expectRevert("Only owner");
        PoolManagementFacet(address(diamond)).createPool(1e17, 7 days, 10);
    }

    function test_DeactivatePoolOnlyOwner() public {
        vm.prank(owner);
        PoolManagementFacet(address(diamond)).createPool(1e17, 7 days, 10);

        vm.prank(user1);
        vm.expectRevert("Only owner");
        PoolManagementFacet(address(diamond)).deactivatePool(0);
    }

}
