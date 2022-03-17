/**
 * VotePool Test
 *
 * VotePool use a token (sHakka), people stake the token
 * into the pool to get boosted. Boosting will make them
 * earn upto 2.5x (for now) than without boosting.
 *
 */

import { expect } from "chai";
import { BigNumber } from "ethers";
import hre from "hardhat";
import { MasterChefMock, VotePool } from "../../typechain";

describe("VotePool", () => {
  let masterChef: MasterChefMock;
  let votePool: VotePool;
  let sHakka;
  const depositAmount = hre.ethers.utils.parseEther("1");
  const votes = hre.ethers.utils.parseEther("1");

  before(async () => {
    const SHakka = await hre.ethers.getContractFactory("ERC20Mock");
    const MasterChef = await hre.ethers.getContractFactory("MasterChefMock");
    const signers = await hre.ethers.getSigners();
    [sHakka, masterChef] = await Promise.all([
      SHakka.deploy(),
      MasterChef.deploy(),
    ]);

    const VotePoolF = await hre.ethers.getContractFactory("VotePool");
    votePool = await VotePoolF.deploy(masterChef.address, sHakka.address);
    await Promise.all([
      masterChef.setPool(votePool.address),
      sHakka["faucet(uint256)"](hre.ethers.utils.parseEther("10")),
      sHakka.connect(signers[1])["faucet(uint256)"](hre.ethers.utils.parseEther("10")),
      sHakka.approve(votePool.address, hre.ethers.utils.parseEther("10")),
      sHakka.connect(signers[1]).approve(votePool.address, hre.ethers.utils.parseEther("10")),
    ]);
    
  });

  describe("LP Change", () => {
    it("Should compute new contribution correctly", async () => {
      const signers = await hre.ethers.getSigners();

      expect(await masterChef.contribution(1, signers[0].address)).equal(
        BigNumber.from("0")
      );

      await masterChef.deposit(1, depositAmount);

      expect(await masterChef.contribution(1, signers[0].address)).equal(
        depositAmount.mul(4).div(10)
      );
      expect(await masterChef.getUserAmount(1, signers[0].address)).equal(
        depositAmount
      );

      await masterChef.withdraw(1, depositAmount.div(2));

      expect(await masterChef.contribution(1, signers[0].address)).equal(
        depositAmount.div(2).mul(4).div(10)
      );
      expect(await masterChef.getUserAmount(1, signers[0].address)).equal(
        depositAmount.div(2)
      );

      await masterChef.deposit(1, depositAmount.div(2));
    });
  });

  describe("Vote Change", () => {
    it("Should compute new weight correctly", async () => {
      const signers = await hre.ethers.getSigners();

      expect(await masterChef.getPoolWeight(1)).equal(
        BigNumber.from("0")
      );

      await votePool.voteForPoolWeight(1, votes);

      expect(await votePool.userWeight(1, signers[0].address)).equal(
        votes
      );

      expect(await masterChef.getPoolWeight(1)).equal(
        votes
      );
    });
  });

  describe("Vote and LP Change", () => {
    it("Should enable boosting correctly", async () => {
      const signers = await hre.ethers.getSigners();

      expect(await masterChef.contribution(1, signers[0].address)).equal(
        depositAmount
      );

      await masterChef.withdraw(1, depositAmount.div(2));

      expect(await masterChef.contribution(1, signers[0].address)).equal(
        depositAmount.div(2)
      );

      await votePool.connect(signers[1]).voteForPoolWeight(1, votes);
      await masterChef.deposit(1, depositAmount.div(2));

      expect(await masterChef.contribution(1, signers[0].address)).equal(
        depositAmount.mul(4).div(10).add(depositAmount.div(2)) // 0.4 + 1e18 / 2e18
      );
    });
  });
});
