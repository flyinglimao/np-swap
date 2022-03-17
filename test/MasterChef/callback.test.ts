/**
 * Callback Test for MasterChef
 * It should trigger callback correctly and use latest data after callback.
 */

import { expect } from "chai";
import hre from "hardhat";
import { MasterChef, Pool, PoolMock } from "../../typechain";

describe("MasterChef Callback", () => {
  let masterChef: MasterChef;
  let pool: PoolMock;
  let hakka;
  let lpToken;

  before(async () => {
    const signers = await hre.ethers.getSigners();
    const ERC20Mock = await hre.ethers.getContractFactory("ERC20Mock");
    hakka = await ERC20Mock.deploy();
    lpToken = await ERC20Mock.deploy();

    const MasterChefF = await hre.ethers.getContractFactory("MasterChef");
    masterChef = await MasterChefF.deploy(
      hakka.address,
      1000,
      signers[0].address,
      1,
      1000
    );

    const Pool = await hre.ethers.getContractFactory("PoolMock");
    pool = await Pool.deploy(masterChef.address);

    await Promise.all([
      masterChef.createPool(lpToken.address, pool.address),
      lpToken["faucet(uint256)"](hre.ethers.utils.parseEther("10")),
      lpToken.approve(masterChef.address, hre.ethers.utils.parseEther("10")),
    ]);
  });

  it("Should trigger onLPUpdated", async () => {
    const tx = await masterChef.deposit(0, hre.ethers.utils.parseEther("1"));
    const callbackTopic = pool.filters.Callback(null).topics![0];
    const filteredEvent = (await tx.wait()).events?.filter(
      (e) =>
        e.topics[0] === callbackTopic &&
        hre.ethers.utils.defaultAbiCoder.decode(["string"], e.data)[0] ==
          "onPoolWillUpdate"
    );

    expect(filteredEvent?.length).equals(1);
  });

  it("Should trigger onPoolWillUpdate and onPoolDidUpdate", async () => {
    const tx = await masterChef.updatePool(0);
    const callbackTopic = pool.filters.Callback(null).topics![0];
    const willUpdateEvent = (await tx.wait()).events?.filter(
      (e) =>
        e.topics[0] === callbackTopic &&
        hre.ethers.utils.defaultAbiCoder.decode(["string"], e.data)[0] ==
          "onPoolWillUpdate"
    );
    const didUpdateEvent = (await tx.wait()).events?.filter(
      (e) =>
        e.topics[0] === callbackTopic &&
        hre.ethers.utils.defaultAbiCoder.decode(["string"], e.data)[0] ==
          "onPoolDidUpdate"
    );

    expect(willUpdateEvent?.length).equals(
      1,
      "onPoolWillUpdate Not Triggered"
    );

    expect(didUpdateEvent?.length).equals(
      1,
      "onPoolDidUpdate Not Triggered"
    );
  });
});
