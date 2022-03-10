//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "../IPool.sol";

/**
 * VotePool will adjust contribution according to votes.
 * Users' contribution is simple equal to the amount of LP put in.
 * Pool weight is computed from users' votes.
 */

contract VotePool is Pool, IPoolCallbackLPUpdated {
  IERC20 public immutable sHakka; // expected to be the voting power contract

  uint256 public constant BOOSTING = 4;
  uint256 public constant BOOSTING_BASIS = 10;

  mapping(address => uint256) public userWeight;

  constructor(MasterChef masterChef_, IERC20 sHakka_) Pool(masterChef_) {
    sHakka = sHakka_;
  }

  /// @notice Allocating voting power for changing pool weight
  /// @param poolId Index of the target pool in `poolInfo`
  /// @param weight Weight for a pool
  function voteForPoolWeight(uint256 poolId, uint256 weight) external {
    // transfer sHakka from user to pool
    sHakka.transferFrom(msg.sender, address(this), weight);
    userWeight[msg.sender] += weight;
    // update pool weight and total weight
    uint256 newWeight = masterChef.getPoolWeight(poolId) + weight;
    masterChef.setWeight(poolId, newWeight);

    // update user contribution, maxmium is 2.5x
    uint256 userAmount = masterChef.getUserAmount(poolId, msg.sender);
    uint256 newContribution = Math.min(
      userAmount,
      userAmount *
        (BOOSTING / BOOSTING_BASIS + userWeight[msg.sender] / newWeight)
    );
    // update user reward debt
    masterChef.setUserContribution(poolId, msg.sender, newContribution);
  }

  /// @notice Revokeing voting power for changing pool weight
  /// @param poolId Index of the target pool in `poolInfo`
  /// @param weight Weight to revoke for a pool, revoke all if larger than allocated
  function unvoteForPoolWeight(uint256 poolId, uint256 weight) external {
    // transfer sHakka from user to pool
    sHakka.transferFrom(msg.sender, address(this), weight);
    userWeight[msg.sender] -= weight;

    // update pool weight and total weight
    uint256 newWeight = masterChef.getPoolWeight(poolId) - weight;
    masterChef.setWeight(poolId, newWeight);

    // update user contribution, maxmium is 2.5x
    uint256 userAmount = masterChef.getUserAmount(poolId, msg.sender);
    uint256 newContribution = Math.min(
      userAmount,
      userAmount *
        (BOOSTING / BOOSTING_BASIS + userWeight[msg.sender] / newWeight)
    );
    // update user reward debt
    // we can't assert if new contribution is higher or lower
    masterChef.setUserContribution(poolId, msg.sender, newContribution);
  }

  function onLPUpdated(
    uint256 poolId,
    address user,
    uint256 newAmount
  ) external override onlyMasterChef returns (bytes4) {
    uint256 newContribution = Math.min(
      newAmount,
      (newAmount * BOOSTING) /
        BOOSTING_BASIS +
        userWeight[user] /
        masterChef.getPoolWeight(poolId)
    );
    // update user reward debt
    // we can't assert if new contribution is higher or lower
    masterChef.setUserContribution(poolId, user, newContribution);

    return this.onLPUpdated.selector;
  }
}
