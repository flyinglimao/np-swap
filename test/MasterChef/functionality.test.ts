/**
 * Functionality Test for MasterChef
 * It should work for each function, and revert with reason correctly.
 */

import { expect, use } from "chai";
import hre from "hardhat";
import { ERC20Mock, MasterChef, PoolMock, SimplePool } from "../../typechain";
import chaiAsPromised from "chai-as-promised";

use(chaiAsPromised);

describe("MasterChef Functionality", () => {
  let masterChef: MasterChef;
  let pool: SimplePool;
  let hakka;
  let lpToken: ERC20Mock;

  const rewardPerBlock = hre.ethers.utils.parseEther("1000");
  const protocolFee = 1;
  const protocolFeeBasis = 1000;

  let weightBlock: number;

  before(async () => {
    const signers = await hre.ethers.getSigners();
    const ERC20MockF = await hre.ethers.getContractFactory("ERC20Mock");
    hakka = await ERC20MockF.deploy();
    lpToken = await ERC20MockF.deploy();

    const MasterChefF = await hre.ethers.getContractFactory("MasterChef");
    masterChef = await MasterChefF.deploy(
      hakka.address,
      rewardPerBlock,
      signers[0].address,
      protocolFee,
      protocolFeeBasis
    );

    const Pool = await hre.ethers.getContractFactory("SimplePool");
    pool = await Pool.deploy(masterChef.address);
    await Promise.all([
      masterChef.createPool(lpToken.address, pool.address),
      lpToken["faucet(uint256)"](hre.ethers.utils.parseEther("10")),
      lpToken.approve(masterChef.address, hre.ethers.utils.parseEther("10")),
      lpToken
        .connect(signers[1])
        ["faucet(uint256)"](hre.ethers.utils.parseEther("10")),
      lpToken
        .connect(signers[1])
        .approve(masterChef.address, hre.ethers.utils.parseEther("10")),
    ]);
  });

  it("Should compute reward correctly when update pool", async () => {
    const weightTx = await pool.setWeight(0, 1);
    weightBlock = weightTx.blockNumber!;
    let updateTx = await masterChef.updatePool(0);
    let poolInfo = await masterChef.poolInfo(0);
    expect(poolInfo.unsharedReward).equals(
      rewardPerBlock
        .mul(updateTx.blockNumber! - weightTx.blockNumber!)
        .mul(protocolFeeBasis - protocolFee)
        .div(protocolFeeBasis)
    );

    await masterChef.deposit(0, hre.ethers.utils.parseEther("1"));
    updateTx = await masterChef.updatePool(0);
    poolInfo = await masterChef.poolInfo(0);
    expect(
      poolInfo.unsharedReward.add(
        poolInfo.accRewardPerContribution.mul(poolInfo.totalContribution)
      )
    ).equals(
      rewardPerBlock
        .mul(updateTx.blockNumber! - weightTx.blockNumber!)
        .mul(protocolFeeBasis - protocolFee)
        .div(protocolFeeBasis)
    );
    expect(poolInfo.unsharedReward.lt(poolInfo.totalContribution)).to.be.true;
  });

  it("Should claim reward correctly", async () => {
    const signers = await hre.ethers.getSigners();
    let updateTx = await masterChef.updatePool(0);
    expect(await masterChef.callStatic["claimReward(uint256)"](0)).equals(
      rewardPerBlock
        .mul(updateTx.blockNumber! - weightBlock!)
        .mul(protocolFeeBasis - protocolFee)
        .div(protocolFeeBasis)
    );

    // make withdraw and deposit in same block
    await hre.network.provider.send("evm_setAutomine", [false]);

    const txs = Promise.all([
      masterChef.withdraw(0, hre.ethers.utils.parseEther("0.5")),
      masterChef
        .connect(signers[1])
        .deposit(0, hre.ethers.utils.parseEther("0.5")),
    ]);

    await hre.network.provider.send("evm_mine", []);
    await hre.network.provider.send("evm_setAutomine", [true]);
    const [withdrawTx, depositTx] = await txs;

    updateTx = await masterChef.updatePool(0);

    expect(await masterChef.callStatic["claimReward(uint256)"](0)).equals(
      rewardPerBlock
        .mul(updateTx.blockNumber! - withdrawTx.blockNumber!)
        .mul(protocolFeeBasis - protocolFee)
        .div(protocolFeeBasis)
        .div(2)
    );
  });
});
