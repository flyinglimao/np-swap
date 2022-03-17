//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "../IPool.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/** 
 * SimplePool acts like normal swap LP pool.
 * Users' contribution is simple equal to the amount of LP put in.
 * Pool weight is mannually set.
 */

contract PoolMock is Pool, IPoolCallback {
  event Callback(string callback);

  constructor(MasterChef masterChef_) Pool(masterChef_) {}

  function setWeight(uint256 poolId, uint256 weight) external {
    masterChef.setWeight(poolId, weight);
  }

  function onLPUpdated(uint256 poolId, address user, uint256 newAmount) external override onlyMasterChef returns (bytes4) {
    emit Callback("onLPUpdated");
    return this.onLPUpdated.selector;
  }
  function onPoolWillUpdate(uint256 poolId) external override returns (bytes4) {
    emit Callback("onPoolWillUpdate");
    return this.onPoolWillUpdate.selector;
  }
  function onPoolDidUpdate(uint256 poolId) external override returns (bytes4) {
    emit Callback("onPoolDidUpdate");
    return this.onPoolDidUpdate.selector;
  }
}
