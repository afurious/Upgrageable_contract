// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "../interfaces/IDiamondCut.sol";
import "../libraries/LibDiamond.sol";
import "../libraries/LibStakingStorage.sol";

/**
 * @title DiamondCutFacet
 * @dev Facet for managing diamond cuts and upgrades
 */
contract DiamondCutFacet is IDiamondCut {
    modifier onlyOwner() {
        require(msg.sender == LibStakingStorage.getOwner(), "Only owner");
        _;
    }

    function diamondCut(
        FacetCut[] calldata _diamondCut,
        address _init,
        bytes calldata _calldata
    ) external override onlyOwner {
        LibDiamond.diamondCut(_diamondCut, _init, _calldata);
    }
}
