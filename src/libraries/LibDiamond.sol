// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "../interfaces/IDiamondCut.sol";

/**
 * @title LibDiamond
 * @dev Diamond pattern library for managing facets and cuts
 */
library LibDiamond {
    bytes32 constant DIAMOND_STORAGE_POSITION = keccak256("diamond.standard.diamond.storage");

    struct DiamondStorage {
        mapping(bytes4 => address) selectorToFacet;
        mapping(address => mapping(bytes4 => bool)) facetFunctionSelectors;
        address[] facetAddresses;
        mapping(address => uint16) facetAddressPosition;
        mapping(bytes4 => uint16) selectorPosition;
        bytes4[] selectors;
    }

    event DiamondCut(IDiamondCut.FacetCut[] _diamondCut, address _init, bytes _calldata);

    function diamondStorage() internal pure returns (DiamondStorage storage ds) {
        bytes32 position = DIAMOND_STORAGE_POSITION;
        assembly {
            ds.slot := position
        }
    }

    function addCut(
        DiamondStorage storage ds,
        address _facetAddress,
        bytes4[] memory _functionSelectors
    ) internal {
        require(_facetAddress != address(0), "Invalid facet address");
        for (uint256 i = 0; i < _functionSelectors.length; i++) {
            bytes4 selector = _functionSelectors[i];
            require(ds.selectorToFacet[selector] == address(0), "Selector already exists");
            ds.selectorToFacet[selector] = _facetAddress;
            ds.facetFunctionSelectors[_facetAddress][selector] = true;
        }
        addFacetAddress(ds, _facetAddress);
    }

    function replaceCut(
        DiamondStorage storage ds,
        address _facetAddress,
        bytes4[] memory _functionSelectors
    ) internal {
        require(_facetAddress != address(0), "Invalid facet address");
        for (uint256 i = 0; i < _functionSelectors.length; i++) {
            bytes4 selector = _functionSelectors[i];
            address oldFacet = ds.selectorToFacet[selector];
            require(oldFacet != address(0), "Selector does not exist");
            require(oldFacet != _facetAddress, "Same facet address");
            ds.selectorToFacet[selector] = _facetAddress;
            ds.facetFunctionSelectors[oldFacet][selector] = false;
            ds.facetFunctionSelectors[_facetAddress][selector] = true;
        }
        if (ds.facetFunctionSelectors[_facetAddress][bytes4(0)] == false) {
            addFacetAddress(ds, _facetAddress);
        }
    }

    function removeCut(
        DiamondStorage storage ds,
        bytes4[] memory _functionSelectors
    ) internal {
        for (uint256 i = 0; i < _functionSelectors.length; i++) {
            bytes4 selector = _functionSelectors[i];
            address facet = ds.selectorToFacet[selector];
            require(facet != address(0), "Selector does not exist");
            delete ds.selectorToFacet[selector];
            ds.facetFunctionSelectors[facet][selector] = false;
        }
    }

    function addFacetAddress(DiamondStorage storage ds, address _facetAddress) internal {
        if (ds.facetAddressPosition[_facetAddress] == 0) {
            ds.facetAddresses.push(_facetAddress);
            ds.facetAddressPosition[_facetAddress] = uint16(ds.facetAddresses.length);
        }
    }

    function diamondCut(
        IDiamondCut.FacetCut[] memory _diamondCut,
        address _init,
        bytes memory _calldata
    ) internal {
        DiamondStorage storage ds = diamondStorage();
        
        for (uint256 i = 0; i < _diamondCut.length; i++) {
            IDiamondCut.FacetCut memory cut = _diamondCut[i];
            if (cut.action == IDiamondCut.FacetCutAction.Add) {
                addCut(ds, cut.facetAddress, cut.functionSelectors);
            } else if (cut.action == IDiamondCut.FacetCutAction.Replace) {
                replaceCut(ds, cut.facetAddress, cut.functionSelectors);
            } else if (cut.action == IDiamondCut.FacetCutAction.Remove) {
                removeCut(ds, cut.functionSelectors);
            }
        }

        emit DiamondCut(_diamondCut, _init, _calldata);

        if (_init != address(0)) {
            initializeDiamondCut(_init, _calldata);
        }
    }

    function initializeDiamondCut(address _init, bytes memory _calldata) internal {
        (bool success, bytes memory error) = _init.delegatecall(_calldata);
        if (!success) {
            if (error.length > 0) {
                assembly {
                    let returndata_size := mload(error)
                    revert(add(32, error), returndata_size)
                }
            }
        }
    }

    function getFacetAddress(bytes4 _functionSelector) internal view returns (address) {
        return diamondStorage().selectorToFacet[_functionSelector];
    }

    function hasFacet(address _facet) internal view returns (bool) {
        return diamondStorage().facetAddressPosition[_facet] != 0;
    }
}
