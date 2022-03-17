//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "./MasterChef.sol";

abstract contract Pool {
  MasterChef public masterChef;

  constructor(MasterChef masterChef_) {
    masterChef = masterChef_;
  }

  modifier onlyMasterChef() {
    require(msg.sender == address(masterChef), "MasterChef: Not approved");
    _;
  }
}

/// @dev Allow MasterChef to call a callback `onLPUpdated`
interface IPoolCallbackLPUpdated {
  /// @notice Called when users' LP is updated
  /// @dev will update isn't necesssary since it's easy for pool to record prev value
  /// @param user Address of the user
  /// @param newAmount Updated LP amount of the user
  /// @return selector Function selector of `onLPUpdate`
  function onLPUpdated(
    uint256 poolId,
    address user,
    uint256 newAmount
  ) external returns (bytes4);
}

/// @dev Allow MasterChef to call a callback `IPoolCallbackPoolWillUpdate`
interface IPoolCallbackPoolWillUpdate {
  /// @notice Called when pool will be updated
  /// @return selector Function selector of `onLPUpdate`
  function onPoolWillUpdate(uint256 poolId) external returns (bytes4);
}

/// @dev Allow MasterChef to call a callback `onPoolDidUpdate`
interface IPoolCallbackPoolDidUpdate {
  /// @notice Called when pool is updated
  /// @return selector Function selector of `onLPUpdate`
  function onPoolDidUpdate(uint256 poolId) external returns (bytes4);
}

/// @dev For use as a type, caller should check which method is actually implemented
interface IPoolCallback is
  IPoolCallbackLPUpdated,
  IPoolCallbackPoolWillUpdate,
  IPoolCallbackPoolDidUpdate
{}
