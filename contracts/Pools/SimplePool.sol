//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "../IPool.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/** 
 * SimplePool acts like normal swap LP pool.
 * Users' contribution is simple equal to the amount of LP put in.
 * Pool weight is mannually set.
 */

contract SimplePool is Pool, IPoolCallbackLPUpdated, Ownable {
  constructor(MasterChef masterChef_) Pool(masterChef_) {}

  function setWeight(uint256 poolId, uint256 weight) external onlyOwner {
    masterChef.setWeight(poolId, weight);
  }

  function onLPUpdated(uint256 poolId, address user, uint256 newAmount) external override onlyMasterChef returns (bytes4) {
    masterChef.setUserContribution(poolId, user, newAmount);
    return this.onLPUpdated.selector;
  }
}
