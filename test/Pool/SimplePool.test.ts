/**
 * SimplePool Test
 *
 * VotePool acts like normal swap.
 *
 */

 import { expect } from "chai";
 import { BigNumber } from "ethers";
 import hre from "hardhat";
 import { MasterChefMock, SimplePool } from "../../typechain";
 
 describe("SimplePool", () => {
   let masterChef: MasterChefMock;
   let simplePool: SimplePool;
   const depositAmount = hre.ethers.utils.parseEther("1");
 
   before(async () => {
     const MasterChef = await hre.ethers.getContractFactory("MasterChefMock");
     masterChef = await MasterChef.deploy();
 
     const SimplePoolF = await hre.ethers.getContractFactory("SimplePool");
     simplePool = await SimplePoolF.deploy(masterChef.address);
     await masterChef.setPool(simplePool.address);
     
   });
 
   describe("LP Change", () => {
     it("Should compute new contribution correctly", async () => {
       const signers = await hre.ethers.getSigners();
 
       expect(await masterChef.contribution(1, signers[0].address)).equal(
         BigNumber.from("0")
       );
 
       await masterChef.deposit(1, depositAmount);
 
       expect(await masterChef.contribution(1, signers[0].address)).equal(
         depositAmount
       );
 
       await masterChef.withdraw(1, depositAmount.div(2));
 
       expect(await masterChef.contribution(1, signers[0].address)).equal(
         depositAmount.div(2)
       );
     });
   });
 });
 