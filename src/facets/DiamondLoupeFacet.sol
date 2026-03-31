// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "../interfaces/IDiamondLoupe.sol";
import "../libraries/LibDiamond.sol";

/**
 * @title DiamondLoupeFacet
 * @dev Facet for querying diamond facets and functions
 */
contract DiamondLoupeFacet is IDiamondLoupe {
    function facets() external view override returns (Facet[] memory facets_) {
        LibDiamond.DiamondStorage storage ds = LibDiamond.diamondStorage();
        facets_ = new Facet[](ds.facetAddresses.length);

        for (uint256 i = 0; i < ds.facetAddresses.length; i++) {
            address currentFacet = ds.facetAddresses[i];
            bytes4[] memory functionSelectors = new bytes4[](0);
            uint256 selectorCount = 0;

            for (uint256 j = 0; j < 65536; j++) {
                bytes4 selector = bytes4(uint32(j));
                if (ds.facetFunctionSelectors[currentFacet][selector]) {
                    selectorCount++;
                }
            }

            functionSelectors = new bytes4[](selectorCount);
            uint256 index = 0;

            for (uint256 j = 0; j < 65536; j++) {
                bytes4 selector = bytes4(uint32(j));
                if (ds.facetFunctionSelectors[currentFacet][selector]) {
                    functionSelectors[index] = selector;
                    index++;
                }
            }

            facets_[i] = Facet({facetAddress: currentFacet, functionSelectors: functionSelectors});
        }
    }

    function facetFunctionSelectors(address _facet) external view override returns (bytes4[] memory) {
        LibDiamond.DiamondStorage storage ds = LibDiamond.diamondStorage();
        uint256 selectorCount = 0;

        for (uint256 i = 0; i < 65536; i++) {
            bytes4 selector = bytes4(uint32(i));
            if (ds.facetFunctionSelectors[_facet][selector]) {
                selectorCount++;
            }
        }

        bytes4[] memory functionSelectors = new bytes4[](selectorCount);
        uint256 index = 0;

        for (uint256 i = 0; i < 65536; i++) {
            bytes4 selector = bytes4(uint32(i));
            if (ds.facetFunctionSelectors[_facet][selector]) {
                functionSelectors[index] = selector;
                index++;
            }
        }

        return functionSelectors;
    }

    function facetAddresses() external view override returns (address[] memory) {
        return LibDiamond.diamondStorage().facetAddresses;
    }

    function facetAddress(bytes4 _functionSelector) external view override returns (address) {
        return LibDiamond.getFacetAddress(_functionSelector);
    }

    function supportsInterface(bytes4 _interfaceId) external pure override returns (bool) {
        return _interfaceId == 0x01ffc9a7 || _interfaceId == type(IDiamondLoupe).interfaceId;
    }
}
