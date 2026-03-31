// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "./libraries/LibDiamond.sol";
import "./libraries/LibStakingStorage.sol";
import "./interfaces/IDiamondCut.sol";

/**
 * @title Diamond
 * @dev Main Diamond proxy contract for StakingRewards
 */
contract Diamond {
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    constructor(
        address _owner,
        address _stakingToken,
        address _diamondCutFacet
    ) {
        require(_owner != address(0), "Invalid owner");
        require(_stakingToken != address(0), "Invalid token");
        require(_diamondCutFacet != address(0), "Invalid facet");

        LibStakingStorage.setOwner(_owner);
        LibStakingStorage.setStakingToken(IERC20(_stakingToken));

        // Add DiamondCutFacet
        LibDiamond.DiamondStorage storage ds = LibDiamond.diamondStorage();
        
        bytes4[] memory diamondCutSelectors = new bytes4[](1);
        diamondCutSelectors[0] = IDiamondCut.diamondCut.selector;
        
        IDiamondCut.FacetCut[] memory cuts = new IDiamondCut.FacetCut[](1);
        cuts[0] = IDiamondCut.FacetCut({
            facetAddress: _diamondCutFacet,
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: diamondCutSelectors
        });

        LibDiamond.diamondCut(cuts, address(0), "");

        emit OwnershipTransferred(address(0), _owner);
    }

    fallback() external payable {
        LibDiamond.DiamondStorage storage ds = LibDiamond.diamondStorage();
        address facet = ds.selectorToFacet[msg.sig];
        require(facet != address(0), "Function does not exist");
        
        assembly {
            calldatacopy(0, 0, calldatasize())
            let result := delegatecall(gas(), facet, 0, calldatasize(), 0, 0)
            returndatacopy(0, 0, returndatasize())
            switch result
            case 0 {
                revert(0, returndatasize())
            }
            default {
                return(0, returndatasize())
            }
        }
    }

    receive() external payable {}
}
