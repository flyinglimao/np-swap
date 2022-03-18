//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "./IPool.sol";

interface RewardToken {
  function mint(address to, uint256 amount) external;
}

// Yeah it is `refer` to Sushi
contract MasterChef is Ownable {
  using SafeERC20 for IERC20;
  using Math for uint256;
  using Address for address;

  /// @notice Info of each user
  struct UserInfo {
    // How many LP tokens the user has provided, used for deposit/withdraw
    uint256 amount;
    // Adjusted LP contribution, used for rewarding
    // Controlled by pool contract
    uint256 contribution;
    uint256 rewardDebt; // Reward debt. See explanation below.
  }

  /// @notice Info of each pool
  struct PoolInfo {
    IERC20 lpToken;
    uint256 totalContribution; // Check the explantion for contributi on in UserInfo
    uint256 weight; // allocPoint but since we are vote-based, renaming it as weight
    uint256 lastRewardBlock;
    // accReward += gain in a time window / total contribution at the moment
    uint256 accRewardPerContribution;
    IPoolCallback pool;
  }

  /// @notice Total weight after a blockNumber
  struct Weight {
    uint256 blockNumber;
    uint256 totalWeight;
    uint256 rewardPerBlock;
  }
  RewardToken public immutable rewardToken;

  /// @notice Info of each pool.
  PoolInfo[] public poolInfo;
  /// @notice `totalAllocPoint` but we use the `weight` instead
  /// @dev Since some pools might not be updated in some time window, we need to store historical total weight
  Weight[] public totalWeight;
  /// @notice Info of each user that stakes LP tokens.
  /// @dev poolId => user addr => user info
  mapping(uint256 => mapping(address => UserInfo)) public userInfo;

  address public protocolFeeRecipent;
  uint256 public protocolFee; // fee = reward * protocolFee / protocolFeeBasis
  uint256 public protocolFeeBasis;

  // events
  // end of events

  constructor(
    RewardToken rewardToken_,
    uint256 rewardPerBlock,
    address protocolFeeRecipent_,
    uint256 protocolFee_,
    uint256 protocolFeeBasis_
  ) {
    rewardToken = rewardToken_;
    totalWeight.push(Weight(block.number, 0, rewardPerBlock));
    protocolFeeRecipent = protocolFeeRecipent_;
    protocolFee = protocolFee_;
    protocolFeeBasis = protocolFeeBasis_;
  }

  /// @notice Get amount of pools
  /// @return amount Amount of pools
  function poolLength() external view returns (uint256) {
    return poolInfo.length;
  }

  /// @notice Create a pool
  /// @dev it basicly equals to add method in sushi's contract
  /// @return id Created pool id
  function createPool(IERC20 lpToken, IPoolCallback poolAddr)
    external
    onlyOwner
    returns (uint256)
  {
    require(address(poolAddr).isContract(), "Pool: Not a contract");

    PoolInfo memory newPool = PoolInfo(
      lpToken,
      0,
      0,
      block.number,
      0,
      poolAddr
    );
    poolInfo.push(newPool);

    uint256 id = poolInfo.length - 1;

    return id;
  }

  /// @notice Update a pool, including weight, reward, etc.
  /// @param poolId Index of the target pool in `poolInfo`
  function updatePool(uint256 poolId) public returns (PoolInfo memory) {
    PoolInfo memory pool = poolInfo[poolId];

    try pool.pool.onPoolWillUpdate(poolId) returns (bytes4 selector) {
      require(
        selector == IPoolCallbackPoolWillUpdate.onPoolWillUpdate.selector,
        "Pool: onPoolWillUpdate Fails"
      );
      // refresh pool info
      pool = poolInfo[poolId];
    } catch (bytes memory reason) {
      if (reason.length != 0) {
        assembly {
          revert(add(32, reason), mload(reason))
        }
      }
    }

    // Compute the reward for the pool based on last reward time and weight
    uint256 poolReward = 0;
    {
      uint256 rewardingFrom = pool.lastRewardBlock;
      uint256 rewardingTo = block.number;
      uint256 weightIndex = totalWeight.length - 1;
      Weight memory rewardingPeriod = totalWeight[weightIndex];
      do {
        // reward per block * pool share * passed blocks
        if (rewardingPeriod.totalWeight > 0)
          poolReward +=
            ((rewardingPeriod.rewardPerBlock * pool.weight) /
              rewardingPeriod.totalWeight) *
            (rewardingTo -
              Math.max(rewardingFrom, rewardingPeriod.blockNumber));
        rewardingTo = rewardingPeriod.blockNumber;

        if (weightIndex == 0) break;
        rewardingPeriod = totalWeight[--weightIndex];
      } while (rewardingFrom < rewardingPeriod.blockNumber);
    }
    // Mint protocol fee to protocol fee recipent
    uint256 fee = (poolReward * protocolFee) / protocolFeeBasis;
    rewardToken.mint(protocolFeeRecipent, fee);
    poolReward -= fee;

    // Update accRewardPerShare
    //   accRewardPerShare += reward / working balance
    if (pool.totalContribution > 0) {
      pool.accRewardPerContribution += poolReward / pool.totalContribution;
    }

    // Mark the pool as updated in current time window
    pool.lastRewardBlock = block.number;

    poolInfo[poolId] = pool;

    try pool.pool.onPoolDidUpdate(poolId) returns (bytes4 selector) {
      require(
        selector == IPoolCallbackPoolDidUpdate.onPoolDidUpdate.selector,
        "Pool: onPoolDidUpdate Fails"
      );
    } catch (bytes memory reason) {
      if (reason.length != 0) {
        assembly {
          revert(add(32, reason), mload(reason))
        }
      }
    }

    return pool;
  }

  /// @notice Update pools with single transaction
  function massUpdatePools() external {
    for (uint256 i = 1; i < poolInfo.length; i++) {
      updatePool(i);
    }
  }

  /// @notice Claim reward for specific pool, staticly call to get rewardable amount
  /// @param poolId Index of the target pool in `poolInfo`
  /// @param to Claimer of rewards.
  /// @param to Receiver of rewards.
  /// @return amount Claimed amount
  function _claimReward(
    uint256 poolId,
    address from,
    address to
  ) private returns (uint256) {
    PoolInfo memory pool = updatePool(poolId);
    UserInfo storage user = userInfo[poolId][from];
    uint256 accReward = user.contribution * pool.accRewardPerContribution;
    uint256 claimable = accReward - user.rewardDebt;

    user.rewardDebt = accReward;
    rewardToken.mint(to, claimable);
    return claimable;
  }

  /// @notice Claim reward for specific pool and send to someone, staticly call to get rewardable amount
  /// @param poolId Index of the target pool in `poolInfo`
  /// @param to Receiver of rewards.
  function claimReward(uint256 poolId, address to) external returns (uint256) {
    return _claimReward(poolId, msg.sender, to);
  }

  /// @notice Claim reward for specific pool, staticly call to get rewardable amount
  /// @param poolId Index of the target pool in `poolInfo`
  function claimReward(uint256 poolId) external returns (uint256) {
    return _claimReward(poolId, msg.sender, msg.sender);
  }

  /// @notice Deposit LP
  /// @param poolId Index of the target pool in `poolInfo`
  /// @param amount Amount of depositing LP tokens
  function deposit(uint256 poolId, uint256 amount) external {
    // user should not be rewarded for prev blocks
    PoolInfo memory pool = updatePool(poolId);
    UserInfo storage user = userInfo[poolId][msg.sender];

    pool.lpToken.safeTransferFrom(msg.sender, address(this), amount);
    user.amount += amount;

    try pool.pool.onLPUpdated(poolId, msg.sender, user.amount) returns (
      bytes4 selector
    ) {
      require(
        selector == IPoolCallbackLPUpdated.onLPUpdated.selector,
        "Pool: onLPUpdated Fails"
      );
    } catch (bytes memory reason) {
      if (reason.length != 0) {
        assembly {
          revert(add(32, reason), mload(reason))
        }
      }
    }
  }

  /// @notice Withdraw LP
  /// @param poolId Index of the target pool in `poolInfo`
  /// @param amount Amount of withdrawing LP tokens
  function withdraw(uint256 poolId, uint256 amount) external {
    // user should not be rewarded for prev blocks
    PoolInfo memory pool = updatePool(poolId);
    UserInfo storage user = userInfo[poolId][msg.sender];

    user.amount -= amount;
    pool.lpToken.transfer(msg.sender, amount);

    try pool.pool.onLPUpdated(poolId, msg.sender, user.amount) returns (
      bytes4 selector
    ) {
      require(
        selector == IPoolCallbackLPUpdated.onLPUpdated.selector,
        "Pool: onLPUpdated Fails"
      );
    } catch (bytes memory reason) {
      if (reason.length != 0) {
        assembly {
          revert(add(32, reason), mload(reason))
        }
      }
    }
  }

  /// @notice Set pool weight
  /// @param poolId Index of the target pool in `poolInfo`
  /// @param newWeight New weight for the pool
  function setWeight(uint256 poolId, uint256 newWeight) external {
    PoolInfo storage pool = poolInfo[poolId];
    Weight memory last = totalWeight[totalWeight.length - 1];
    require(address(pool.pool) == msg.sender, "OnlyPools: Not owned");
    updatePool(poolId);
    totalWeight.push(
      Weight(
        block.number,
        last.totalWeight - pool.weight + newWeight,
        last.rewardPerBlock
      )
    );
    pool.weight = newWeight;
  }

  /// @notice Set user contribution and re-compute
  /// @param poolId Index of the target pool in `poolInfo`
  /// @param userAddr Target user's address
  /// @param newContribution New contribution for the user
  function setUserContribution(
    uint256 poolId,
    address userAddr,
    uint256 newContribution
  ) external {
    PoolInfo memory pool = updatePool(poolId);
    UserInfo memory user = userInfo[poolId][userAddr];
    require(address(pool.pool) == msg.sender, "OnlyPools: Not owned");
    _claimReward(poolId, userAddr, userAddr);

    if (newContribution > user.contribution) {
      user.rewardDebt +=
        (newContribution - user.contribution) *
        pool.accRewardPerContribution;
    } else {
      user.rewardDebt -=
        (user.contribution - newContribution) *
        pool.accRewardPerContribution;
    }
    pool.totalContribution =
      pool.totalContribution -
      user.contribution +
      newContribution;
    user.contribution = newContribution;

    userInfo[poolId][userAddr] = user;
    poolInfo[poolId] = pool;
  }

  function getPoolWeight(uint256 poolId) external view returns (uint256) {
    return poolInfo[poolId].weight;
  }

  function getUserAmount(uint256 poolId, address user)
    external
    view
    returns (uint256)
  {
    return userInfo[poolId][user].amount;
  }
}
