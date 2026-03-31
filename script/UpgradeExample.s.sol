// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "forge-std/Script.sol";
import "../src/interfaces/IDiamondCut.sol";

/**
 * @title UpgradeExample
 * @dev Example script showing how to upgrade a Diamond facet
 * 
 * Usage:
 * 1. Deploy new facet contract
 * 2. Prepare FacetCut array
 * 3. Call diamondCut on the Diamond
 */
contract UpgradeExample is Script {
    function run(address diamondAddress, address newFacetAddress) public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        // Example: Replace an existing facet's function
        IDiamondCut.FacetCut[] memory cuts = new IDiamondCut.FacetCut[](1);

        bytes4[] memory functionSelectors = new bytes4[](1);
        functionSelectors[0] = bytes4(keccak256("someFunction()")); // Replace with actual selector

        cuts[0] = IDiamondCut.FacetCut({
            facetAddress: newFacetAddress,
            action: IDiamondCut.FacetCutAction.Replace, // or Add, Remove
            functionSelectors: functionSelectors
        });

        IDiamondCut(diamondAddress).diamondCut(cuts, address(0), "");

        vm.stopBroadcast();
        console.log("Diamond upgraded successfully!");
    }
}
