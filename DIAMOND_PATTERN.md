# StakingRewards Diamond Pattern Implementation

## Overview
This project has been refactored to use the **Diamond Pattern (EIP-2535)**, a modular and upgradeable smart contract architecture. This allows the staking contract to be upgraded without losing state or requiring token holder migration.

## Architecture

### Main Components

#### 1. **Diamond.sol** - Main Proxy Contract
- Central hub that delegates calls to facets
- Handles initialization with DiamondCutFacet
- Routes function calls via `fallback()` to appropriate facets

#### 2. **Facets** (Modular Logic)
Each facet encapsulates specific functionality:

- **DiamondCutFacet** (`facets/DiamondCutFacet.sol`)
  - Manages diamond upgrades
  - Only accessible by owner
  - Function: `diamondCut()`

- **DiamondLoupeFacet** (`facets/DiamondLoupeFacet.sol`)
  - Provides introspection capabilities
  - Query which facets are active
  - Functions: `facets()`, `facetAddresses()`, `facetAddress()`, `facetFunctionSelectors()`

- **PoolManagementFacet** (`facets/PoolManagementFacet.sol`)
  - Create and manage staking pools
  - Functions: `createPool()`, `updateRewardRate()`, `deactivatePool()`, `getPoolDetails()`

- **StakingFacet** (`facets/StakingFacet.sol`)
  - Core staking functionality
  - Functions: `stake()`, `getUserStakeCount()`

- **RewardsFacet** (`facets/RewardsFacet.sol`)
  - Reward calculations and claims
  - Functions: `getPendingRewards()`, `getTotalPendingRewards()`, `claimRewards()`, `claimAllRewards()`

- **WithdrawalFacet** (`facets/WithdrawalFacet.sol`)
  - Withdrawal operations with penalties
  - Functions: `withdraw()`, `emergencyWithdraw()`

- **AdminFacet** (`facets/AdminFacet.sol`)
  - Administrative functions
  - Functions: `enableEmergencyWithdraw()`, `disableEmergencyWithdraw()`, `recoverTokens()`, `transferOwnership()`

- **ViewFacet** (`facets/ViewFacet.sol`)
  - Read-only utility functions
  - Functions: `getUserStakeDetails()`, `getPoolCount()`, `isEmergencyWithdrawEnabled()`

#### 3. **Storage Libraries**

- **LibStakingStorage.sol** (`libraries/LibStakingStorage.sol`)
  - Centralized storage using the diamond storage pattern
  - Maintains storage layout across upgrades
  - Uses namespaced storage slots to prevent collisions

- **LibDiamond.sol** (`libraries/LibDiamond.sol`)
  - Core diamond pattern logic
  - Manages facet routing and cuts
  - Handles `Add`, `Replace`, and `Remove` actions

#### 4. **Interfaces**

- **IDiamondCut.sol** - DiamondCut interface (EIP-2535 standard)
- **IDiamondLoupe.sol** - DiamondLoupe interface (EIP-2535 standard)

## How Diamond Pattern Works

### 1. **Initialization**
```solidity
// Deploy Diamond with initial DiamondCutFacet
Diamond diamond = new Diamond(owner, stakingToken, diamondCutFacet);
```

### 2. **Adding Facets (via DiamondCut)**
```solidity
IDiamondCut.FacetCut[] memory cuts = new IDiamondCut.FacetCut[](1);
cuts[0] = IDiamondCut.FacetCut({
    facetAddress: address(newFacet),
    action: IDiamondCut.FacetCutAction.Add,
    functionSelectors: selectors
});

IDiamondCut(diamond).diamondCut(cuts, address(0), "");
```

### 3. **Function Routing**
When a function is called on the Diamond:
```
Diamond.fallback() → Lookup facet address from function selector → delegatecall to facet → Execute
```

### 4. **State Access**
All facets access the same storage via LibStakingStorage:
```solidity
LibStakingStorage.StakingStorage storage ds = LibStakingStorage.stakingStorage();
// Access/modify shared state
ds.pools[poolId].rewardRate = newRate;
```

## Deployment

### Prerequisites
1. Set environment variables:
```bash
export PRIVATE_KEY=<your_private_key>
export STAKING_TOKEN=<token_address>
```

### Deploy
```bash
forge script script/DeployStakingDiamond.s.sol:DeployStakingDiamond --rpc-url <RPC_URL> --broadcast
```

## Upgrading the Diamond

### Example: Add a New Feature Facet

1. **Create new facet**:
```solidity
// src/facets/NewFeatureFacet.sol
contract NewFeatureFacet {
    function newFunction() external {
        LibStakingStorage.StakingStorage storage ds = LibStakingStorage.stakingStorage();
        // Implementation
    }
}
```

2. **Prepare diamond cut**:
```solidity
bytes4[] memory selectors = new bytes4[](1);
selectors[0] = NewFeatureFacet.newFunction.selector;

IDiamondCut.FacetCut[] memory cuts = new IDiamondCut.FacetCut[](1);
cuts[0] = IDiamondCut.FacetCut({
    facetAddress: address(newFacet),
    action: IDiamondCut.FacetCutAction.Add,
    functionSelectors: selectors
});
```

3. **Execute upgrade**:
```solidity
IDiamondCut(diamond).diamondCut(cuts, address(0), "");
```

### Example: Replace Function Implementation

```solidity
IDiamondCut.FacetCut[] memory cuts = new IDiamondCut.FacetCut[](1);
cuts[0] = IDiamondCut.FacetCut({
    facetAddress: address(upgradedFacet),
    action: IDiamondCut.FacetCutAction.Replace,  // Replace existing
    functionSelectors: selectors
});

IDiamondCut(diamond).diamondCut(cuts, address(0), "");
```

## Key Benefits

✅ **Modular**: Each facet handles specific functionality  
✅ **Upgradeable**: Add, replace, or remove functions without redeployment  
✅ **State Persistent**: Shared storage across all facets  
✅ **Gas Efficient**: Direct delegatecalls avoid unnecessary copying  
✅ **Standard Compliant**: Follows EIP-2535 Diamond Standard  
✅ **No Migration Required**: Storage layout preserved across upgrades  

## Important Notes

1. **Storage Collisions**: Always use the diamond storage pattern with unique keccak256 positions
2. **Function Selectors**: Keep track of all function selectors for upgrades
3. **Owner Control**: Only contract owner can call `diamondCut()`
4. **Facet Introspection**: Use DiamondLoupeFacet to inspect active facets and functions

## File Structure
```
src/
├── Diamond.sol
├── libraries/
│   ├── LibDiamond.sol
│   └── LibStakingStorage.sol
├── interfaces/
│   ├── IDiamondCut.sol
│   └── IDiamondLoupe.sol
└── facets/
    ├── DiamondCutFacet.sol
    ├── DiamondLoupeFacet.sol
    ├── PoolManagementFacet.sol
    ├── StakingFacet.sol
    ├── RewardsFacet.sol
    ├── WithdrawalFacet.sol
    ├── AdminFacet.sol
    └── ViewFacet.sol

script/
└── DeployStakingDiamond.s.sol
```

## References
- [EIP-2535 Diamond Standard](https://eips.ethereum.org/EIPS/eip-2535)
- [Diamond Upgradeable Pattern Documentation](https://dev.to/mudgen/understanding-the-diamond-pattern-4dkm)
