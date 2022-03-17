/**
 * Access Test for MasterChef
 * It should forbid calls from anyone except pools.
 */

import { expect, use } from "chai";
import hre from "hardhat";
import { ERC20Mock, MasterChef, PoolMock } from "../../typechain";
import chaiAsPromised from 'chai-as-promised';

use(chaiAsPromised);

describe("MasterChef Callback", () => {
  let masterChef: MasterChef;
  let pool: PoolMock;
  let hakka;
  let lpToken: ERC20Mock;

  before(async () => {
    const signers = await hre.ethers.getSigners();
    const ERC20MockF = await hre.ethers.getContractFactory("ERC20Mock");
    hakka = await ERC20MockF.deploy();
    lpToken = await ERC20MockF.deploy();

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
  });

  it("Should forbid non-admin from creating pool", async () => {
    const signers = await hre.ethers.getSigners();

    await expect(masterChef.connect(signers[1]).createPool(lpToken.address, pool.address)).to.eventually.be.rejected;
  });

  it("Should allow admin from creating pool", async () => {
    await expect(masterChef.createPool(lpToken.address, pool.address)).to.eventually.be.fulfilled;
  });

});
 