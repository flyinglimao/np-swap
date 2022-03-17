//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "../IPool.sol";

contract MasterChefMock {
  event Debug(string identifier);

  struct UserInfo {
    uint256 amount;
    uint256 contribution;
    uint256 rewardDebt;
    uint256 weight;
  }

  struct PoolInfo {
    IERC20 lpToken;
    uint256 totalContribution;
    uint256 weight;
    uint256 lastRewardBlock;
    uint256 accRewardPerContribution;
    IPoolCallback pool;
  }

  mapping(uint256 => uint256) public weight;
  mapping(uint256 => mapping(address => uint256)) public contribution;
  mapping(uint256 => mapping(address => uint256)) public lpAmount;
  IPoolCallback public pool;

  function setPool(IPoolCallback pool_) external {
    pool = pool_;
  }

  function setWeight(uint256 poolId, uint256 newWeight)
    external
    returns (PoolInfo memory)
  {
    weight[poolId] = newWeight;
    return PoolInfo(IERC20(address(this)), 0, 0, 0, 0, IPoolCallback(address(this)));
  }

  function setUserContribution(
    uint256 poolId,
    address userAddr,
    uint256 newContribution
  ) external returns (UserInfo memory) {
    contribution[poolId][userAddr] = newContribution;
    return UserInfo(0, 0, 0, 0);
  }

  function getPoolWeight(uint256 poolId) external view returns (uint256) {
    return weight[poolId];
  }

  function getUserAmount(uint256 poolId, address user)
    external
    view
    returns (uint256)
  {
    return lpAmount[poolId][user];
  }

  function deposit(uint256 poolId, uint256 amount) external {
    updatePool(poolId);
    lpAmount[poolId][msg.sender] += amount;
    pool.onLPUpdated(poolId, msg.sender, lpAmount[poolId][msg.sender]);
    try
      pool.onLPUpdated(poolId, msg.sender, lpAmount[poolId][msg.sender])
    returns (bytes4 selector) {
      require(
        selector == IPoolCallbackLPUpdated.onLPUpdated.selector,
        "Pool: onLPUpdated Fails"
      );
      emit Debug("onLPUpdated Triggered");
    } catch (bytes memory reason) {
      if (reason.length != 0) {
        assembly {
          revert(add(32, reason), mload(reason))
        }
      }
      emit Debug("onLPUpdated Not Triggered");
    }
  }

  function withdraw(uint256 poolId, uint256 amount) external {
    updatePool(poolId);
    lpAmount[poolId][msg.sender] -= amount;
    try
      pool.onLPUpdated(poolId, msg.sender, lpAmount[poolId][msg.sender])
    returns (bytes4 selector) {
      require(
        selector == IPoolCallbackLPUpdated.onLPUpdated.selector,
        "Pool: onLPUpdated Fails"
      );
      emit Debug("onLPUpdated Triggered");
    } catch (bytes memory reason) {
      if (reason.length != 0) {
        assembly {
          revert(add(32, reason), mload(reason))
        }
      }
      emit Debug("onLPUpdated Not Triggered");
    }
  }

  function updatePool(uint256 poolId) public {
    try pool.onPoolWillUpdate(poolId) returns (bytes4 selector) {
      require(
        selector == IPoolCallbackPoolWillUpdate.onPoolWillUpdate.selector,
        "Pool: onPoolWillUpdate Fails"
      );
      emit Debug("onPoolWillUpdate Triggered");
    } catch (bytes memory reason) {
      if (reason.length != 0) {
        assembly {
          revert(add(32, reason), mload(reason))
        }
      }
      emit Debug("onPoolWillUpdate Not Triggered");
    }

    try pool.onPoolDidUpdate(poolId) returns (bytes4 selector) {
      require(
        selector == IPoolCallbackPoolDidUpdate.onPoolDidUpdate.selector,
        "Pool: onPoolDidUpdate Fails"
      );
      emit Debug("onPoolDidUpdate Triggered");
    } catch (bytes memory reason) {
      if (reason.length != 0) {
        assembly {
          revert(add(32, reason), mload(reason))
        }
      }
      emit Debug("onPoolDidUpdate Not Triggered");
    }
  }
}
