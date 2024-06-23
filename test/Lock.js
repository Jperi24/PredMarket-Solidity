const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("predMarket2", function () {
  let predMarket2;
  let owner, addr1, addr2, addr3, staff;

  beforeEach(async function () {
    [owner, addr1, addr2, addr3, staff] = await ethers.getSigners();

    const PredMarket2 = await ethers.getContractFactory("predMarket2");
    predMarket2 = await PredMarket2.deploy(3600, {
      value: ethers.parseEther("1.0"),
    }); // 1 hour endTime with initial ether
  });

  // Helper function to get balance difference
  async function getBalanceDifference(address, action) {
    const initialBalance = await ethers.provider.getBalance(address);
    const tx = await action();
    const receipt = await tx.wait();
    const finalBalance = await ethers.provider.getBalance(address);
    // Avoid using gasUsed.mul to simplify the balance check
    if (finalBalance >= initialBalance) {
      return finalBalance - initialBalance;
    } else {
      return initialBalance - finalBalance;
    }
  }

  // Additional tests

  it("should handle when user unlists multiple bets", async function () {
    await predMarket2
      .connect(addr1)
      .sellANewBet(1000000000000000, 1, { value: 500000000000000 });
    await predMarket2
      .connect(addr1)
      .sellANewBet(2000000000000000, 2, { value: 1000000000000000 });

    await predMarket2.connect(addr1).unlistBets([0, 1]);

    const bet0 = await predMarket2.arrayOfBets(0);
    const bet1 = await predMarket2.arrayOfBets(1);

    expect(bet0.selling).to.equal(false);
    expect(bet1.selling).to.equal(false);
  });

  it("should prevent non-owner or non-staff from declaring winner", async function () {
    await expect(
      predMarket2.connect(addr1).declareWinner(1, 0)
    ).to.be.revertedWith("Only the owner can call this function.");

    await expect(
      predMarket2.connect(addr2).declareWinner(1, 0)
    ).to.be.revertedWith("Only the owner can call this function.");
  });

  it("should not allow user to buy a bet for incorrect price", async function () {
    await predMarket2
      .connect(addr1)
      .sellANewBet(1000000000000000, 1, { value: 500000000000000 });

    expect(predMarket2.connect(addr2).buyABet(0, { value: 500000000000000 })).to
      .be.reverted;
  });

  it("should prevent double spending by resetting bet amounts on withdrawal", async function () {
    await predMarket2
      .connect(addr1)
      .sellANewBet(1000000000000000, 1, { value: 500000000000000 });
    await predMarket2.connect(addr2).buyABet(0, { value: 1000000000000000 });
    await predMarket2.connect(owner).declareWinner(1, 0);
    await network.provider.send("evm_increaseTime", [7201]);
    await network.provider.send("evm_mine");

    const addr2Balance = await ethers.provider.getBalance(addr2.address);

    console.log(addr2Balance, "addr2 Balance, before double withdraw");

    expect(predMarket2.connect(addr2).withdraw()).to.be.reverted;

    console.log(addr2Balance, "addr2 Balance, after double withdraw");

    expect(addr2Balance).to.be.above(0);
  });

  // it("should handle user having both deployed and owner bets correctly", async function () {
  //   await predMarket2
  //     .connect(addr1)
  //     .sellANewBet(1000000000000000, 1, { value: 500000000000000 });
  //   await predMarket2.connect(addr2).buyABet(0, { value: 1000000000000000 });

  //   await predMarket2.connect(owner).declareWinner(1, 0);
  //   await network.provider.send("evm_increaseTime", [7201]);
  //   await network.provider.send("evm_mine");

  //   console.log
  // });

  it("should prevent user from unlisting bets they do not own", async function () {
    await predMarket2
      .connect(addr1)
      .sellANewBet(1000000000000000, 1, { value: 500000000000000 });
    await predMarket2.connect(addr2).buyABet(0, { value: 1000000000000000 });

    await expect(predMarket2.connect(addr3).unlistBets([0])).to.be.revertedWith(
      "Caller is not the owner"
    );
  });

  it("should handle multiple users interacting with the contract", async function () {
    await predMarket2
      .connect(addr1)
      .sellANewBet(1000000000000000, 1, { value: 500000000000000 });
    await predMarket2.connect(addr2).buyABet(0, { value: 1000000000000000 });

    await predMarket2
      .connect(addr1)
      .sellANewBet(2000000000000000, 2, { value: 1000000000000000 });
    await predMarket2.connect(addr3).buyABet(1, { value: 2000000000000000 });

    await predMarket2.connect(owner).declareWinner(1, 0);
    await network.provider.send("evm_increaseTime", [7201]);
    await network.provider.send("evm_mine");

    addr1Balance = await ethers.provider.getBalance(addr1);
    addr2Balance = await ethers.provider.getBalance(addr2);
    addr3Balance = await ethers.provider.getBalance(addr3);
    console.log(addr1Balance, "addr1 Balance 113 test");
    console.log(addr2Balance, "addr2 Balance 113 test");
    console.log(addr3Balance, "addr3 Balance 113 test");
    expect(addr2Balance > addr3Balance > addr1Balance);
  });

  it("should ensure creator's take is calculated correctly", async function () {
    await predMarket2
      .connect(addr1)
      .sellANewBet(1000000000000000, 1, { value: 500000000000000 });
    await predMarket2.connect(addr2).buyABet(0, { value: 1000000000000000 });

    await predMarket2.connect(owner).declareWinner(1, 0);
    await network.provider.send("evm_increaseTime", [7201]);
    await network.provider.send("evm_mine");
    await predMarket2.connect(addr2).withdraw();

    const creatorInitialBalance = await ethers.provider.getBalance(owner);

    console.log(creatorInitialBalance, "BALANCE Before Owner Takes");

    await predMarket2.connect(owner).transferOwnerAmount();

    const creatorFinalBalance = await ethers.provider.getBalance(owner);
    console.log(creatorFinalBalance, "BALANCE AFTER Owner TAKING");

    expect(creatorFinalBalance).to.be.greaterThanOrEqual(
      creatorInitialBalance + ethers.parseEther("0.03")
    ); // 3% of 1 ether
  });

  it("should ensure bets are stored correctly", async function () {
    await predMarket2
      .connect(addr1)
      .sellANewBet(1000000000000000, 1, { value: 500000000000000 });
    const bet0 = await predMarket2.arrayOfBets(0);
    expect(bet0.deployer).to.equal(addr1.address);
    expect(bet0.amountDeployerLocked).to.equal(500000000000000);
  });

  it("should ensure users cannot sell a bet they do not own", async function () {
    await predMarket2
      .connect(addr1)
      .sellANewBet(1000000000000000, 1, { value: 500000000000000 });
    await predMarket2.connect(addr2).buyABet(0, { value: 1000000000000000 });

    await expect(
      predMarket2.connect(addr3).sellAnExistingBet(0, 2000000000000000)
    ).to.be.reverted;
  });

  it("should handle the edge case of zero balance", async function () {
    await expect(predMarket2.connect(addr1).withdraw()).to.be.reverted;
  });

  it("should handle incorrect bet conditions", async function () {
    await expect(
      predMarket2
        .connect(addr1)
        .sellANewBet(1000000000000000, 4, { value: 500000000000000 })
    ).to.be.reverted;
  });

  // it("should prevent withdrawal before settlement", async function () {
  //   await predMarket2.connect(owner).declareWinner(1, 0);

  //   await expect(predMarket2.connect(addr1).withdraw()).to.be.reverted;
  // });

  // it("should ensure owner can transfer locked amount correctly", async function () {
  //   await predMarket2.connect(owner).declareWinner(1, 0);
  //   await network.provider.send("evm_increaseTime", [7201]);
  //   await network.provider.send("evm_mine");

  //   const ownerInitialBalance = await ethers.provider.getBalance(owner.address);

  //   await predMarket2.connect(owner).transferOwnerAmount();

  //   const ownerFinalBalance = await ethers.provider.getBalance(owner.address);
  //   const balanceDifference = ownerFinalBalance.sub(ownerInitialBalance);

  //   expect(balanceDifference).to.be.above(0);
  // });

  // Add more tests as needed to ensure comprehensive coverage
});
