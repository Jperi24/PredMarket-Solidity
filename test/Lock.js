const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("predMarket", function () {
  this.timeout(60000);
  it("Deployment should assign the total supply of tokens to the owner", async function () {
    const [owner, user1, user2, user3, user4] = await ethers.getSigners();

    const predMarketI = await ethers.getContractFactory("predMarket");
    const predMarket = await predMarketI.deploy(86400, 2, 1);

    console.log((await ethers.provider.getBalance(owner.address)) + " owner");
    console.log((await ethers.provider.getBalance(user1.address)) + " user1");
    console.log((await ethers.provider.getBalance(user2.address)) + " user2");
    console.log((await ethers.provider.getBalance(user3.address)) + " user3");

    console.log(
      (await ethers.provider.getBalance(user1.address)) + " before bett"
    );
    await predMarket
      .connect(user1)
      .betOnBetA({ value: ethers.parseEther("100") });
    console.log(
      (await ethers.provider.getBalance(user1.address)) + " afte Bet"
    );
    // await predMarket
    //   .connect(user2)
    //   .betOnBetA({ value: ethers.parseEther("100") });
    await predMarket
      .connect(user3)
      .betOnBetB({ value: ethers.parseEther("10") });
    console.log((await ethers.provider.getBalance(owner.address)) + " owner");
    console.log((await ethers.provider.getBalance(user1.address)) + " user1");
    console.log((await ethers.provider.getBalance(user2.address)) + " user2");
    console.log((await ethers.provider.getBalance(user3.address)) + " user3");

    //await predMarket.returnAll()
    console.log((await ethers.provider.getBalance(owner.address)) + " owner");
    console.log((await ethers.provider.getBalance(user1.address)) + " user1");
    console.log((await ethers.provider.getBalance(user2.address)) + " user2");
    console.log((await ethers.provider.getBalance(user3.address)) + " user3");
    console.log("got here");
  });
});
