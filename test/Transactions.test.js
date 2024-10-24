// test/predMarket2.test.js

const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("predMarket2 Contract Tests", function () {
  let predMarket2;
  let owner;
  let staff;
  let addr1;
  let addr2;
  let addr3;
  let addrs;

  const betAmount = ethers.parseEther("1"); // 1 ETH
  const buyPrice = ethers.parseEther("0.5"); // 0.5 ETH

  beforeEach(async function () {
    // Get signers
    [owner, staff, addr1, addr2, addr3, ...addrs] = await ethers.getSigners();

    // Deploy the contract with a future endTime (1 hour from now)
    const PredMarket2 = await ethers.getContractFactory("predMarket2");
    predMarket2 = await PredMarket2.deploy(
      Math.floor(Date.now() / 1000) + 3600
    );

    // Adjust staff wallet if necessary (ensure staff address matches)
    // For testing, we'll assume staff is the second signer
    await predMarket2.connect(owner).transferOwnership(owner.address);
    predMarket2 = predMarket2.connect(owner);
  });

  // Helper functions
  async function createAndSellBet(seller, condition) {
    // Seller creates a new bet
    await predMarket2.connect(seller).sellANewBet(buyPrice, condition, {
      value: betAmount,
    });
  }

  async function buyBet(buyer, betPosition) {
    // Buyer purchases the bet
    await predMarket2.connect(buyer).buyABet(betPosition, {
      value: buyPrice,
    });
  }

  // Function to simulate time increase
  async function increaseTime(seconds) {
    await ethers.provider.send("evm_increaseTime", [seconds]);
    await ethers.provider.send("evm_mine", []);
  }

  describe("Scenario when winner is 1", function () {
    it("Should correctly transfer funds when winner is 1", async function () {
      // addr1 creates a bet with condition 1
      await createAndSellBet(addr1, 1);

      // addr2 buys the bet from addr1
      await buyBet(addr2, 0);

      // Staff declares winner as 1
      await predMarket2.connect(owner).declareWinner(1);

      // Simulate time passing beyond endOfVoting
      await increaseTime(400); // Assuming endOfVoting is 300 seconds after declaring winner

      // addr2 (current owner) withdraws funds
      const addr2InitialBalance = await ethers.provider.getBalance(
        addr2.address
      );
      const txWithdraw = await predMarket2.connect(addr2).withdraw();
      const receipt = await txWithdraw.wait();
      const gasUsed = receipt.gasUsed.mul(receipt.effectiveGasPrice);
      const addr2FinalBalance = await ethers.provider.getBalance(addr2.address);
      const addr2BalanceChange = addr2FinalBalance
        .sub(addr2InitialBalance)
        .add(gasUsed);

      // addr2 should receive betAmount + buyPrice - fees
      const totalPayout = betAmount.add(buyPrice);
      const creatorFee = totalPayout.mul(2).div(100); // 2% owner fee
      const staffFee = totalPayout.mul(3).div(100); // 3% staff fee
      const expectedPayout = totalPayout.sub(creatorFee).sub(staffFee);
      expect(addr2BalanceChange).to.equal(expectedPayout);

      // addr1 (original deployer) should not receive any funds
      await expect(predMarket2.connect(addr1).withdraw()).to.be.revertedWith(
        "No balance to withdraw"
      );
    });
  });

  describe("Scenario when winner is 2", function () {
    it("Should correctly transfer funds when winner is 2", async function () {
      // addr1 creates a bet with condition 1
      await createAndSellBet(addr1, 1);

      // addr2 buys the bet from addr1
      await buyBet(addr2, 0);

      // Staff declares winner as 2
      await predMarket2.connect(owner).declareWinner(2);

      // Simulate time passing beyond endOfVoting
      await increaseTime(400);

      // addr1 (original deployer) withdraws funds
      const addr1InitialBalance = await ethers.provider.getBalance(
        addr1.address
      );
      const txWithdraw = await predMarket2.connect(addr1).withdraw();
      const receipt = await txWithdraw.wait();
      const gasUsed = receipt.gasUsed.mul(receipt.effectiveGasPrice);
      const addr1FinalBalance = await ethers.provider.getBalance(addr1.address);
      const addr1BalanceChange = addr1FinalBalance
        .sub(addr1InitialBalance)
        .add(gasUsed);

      // addr1 should receive betAmount + buyPrice - fees
      const totalPayout = betAmount.add(buyPrice);
      const creatorFee = totalPayout.mul(2).div(100); // 2% owner fee
      const staffFee = totalPayout.mul(3).div(100); // 3% staff fee
      const expectedPayout = totalPayout.sub(creatorFee).sub(staffFee);
      expect(addr1BalanceChange).to.equal(expectedPayout);

      // addr2 (current owner) should not receive any funds
      await expect(predMarket2.connect(addr2).withdraw()).to.be.revertedWith(
        "No balance to withdraw"
      );
    });
  });

  describe("Scenario when winner is 3 (refund)", function () {
    it("Should refund all participants when winner is 3", async function () {
      // addr1 creates a bet with condition 1
      await createAndSellBet(addr1, 1);

      // addr2 buys the bet from addr1
      await buyBet(addr2, 0);

      // Staff declares winner as 3
      await predMarket2.connect(owner).declareWinner(3);

      // No need to increase time since s_raffleState is directly set to SETTLED

      // addr1 withdraws funds (should get back the deployer amount)
      const addr1InitialBalance = await ethers.provider.getBalance(
        addr1.address
      );
      const txWithdraw1 = await predMarket2.connect(addr1).withdraw();
      const receipt1 = await txWithdraw1.wait();
      const gasUsed1 = receipt1.gasUsed.mul(receipt1.effectiveGasPrice);
      const addr1FinalBalance = await ethers.provider.getBalance(addr1.address);
      const addr1BalanceChange = addr1FinalBalance
        .sub(addr1InitialBalance)
        .add(gasUsed1);

      expect(addr1BalanceChange).to.equal(betAmount);

      // addr2 withdraws funds (should get back the buy price)
      const addr2InitialBalance = await ethers.provider.getBalance(
        addr2.address
      );
      const txWithdraw2 = await predMarket2.connect(addr2).withdraw();
      const receipt2 = await txWithdraw2.wait();
      const gasUsed2 = receipt2.gasUsed.mul(receipt2.effectiveGasPrice);
      const addr2FinalBalance = await ethers.provider.getBalance(addr2.address);
      const addr2BalanceChange = addr2FinalBalance
        .sub(addr2InitialBalance)
        .add(gasUsed2);

      expect(addr2BalanceChange).to.equal(buyPrice);
    });
  });

  describe("Additional Scenarios and Edge Cases", function () {
    it("Should prevent withdrawal before settlement", async function () {
      await createAndSellBet(addr1, 1);
      await buyBet(addr2, 0);
      await predMarket2.connect(owner).declareWinner(1);

      // Try to withdraw immediately without increasing time
      await expect(predMarket2.connect(addr2).withdraw()).to.be.revertedWith(
        "Cannot withdraw at this time"
      );

      // Simulate time passing beyond endOfVoting
      await increaseTime(400);

      // Now withdrawal should be allowed
      await expect(predMarket2.connect(addr2).withdraw()).not.to.be.reverted;
    });

    it("Should handle multiple bets and participants correctly", async function () {
      // addr1 creates and sells multiple bets
      await createAndSellBet(addr1, 1);
      await createAndSellBet(addr1, 2);

      // addr2 buys the first bet
      await buyBet(addr2, 0);

      // addr3 buys the second bet
      await buyBet(addr3, 1);

      // Staff declares winner as 1
      await predMarket2.connect(owner).declareWinner(1);
      await increaseTime(400);

      // addr2 (bet on condition 1) should receive payout
      const addr2InitialBalance = await ethers.provider.getBalance(
        addr2.address
      );
      const txWithdraw2 = await predMarket2.connect(addr2).withdraw();
      const receipt2 = await txWithdraw2.wait();
      const gasUsed2 = receipt2.gasUsed.mul(receipt2.effectiveGasPrice);
      const addr2FinalBalance = await ethers.provider.getBalance(addr2.address);
      const addr2BalanceChange = addr2FinalBalance
        .sub(addr2InitialBalance)
        .add(gasUsed2);

      // Expected payout for addr2
      const totalPayout2 = betAmount.add(buyPrice);
      const creatorFee2 = totalPayout2.mul(2).div(100);
      const staffFee2 = totalPayout2.mul(3).div(100);
      const expectedPayout2 = totalPayout2.sub(creatorFee2).sub(staffFee2);
      expect(addr2BalanceChange).to.equal(expectedPayout2);

      // addr3 (bet on condition 2) should not receive any funds
      await expect(predMarket2.connect(addr3).withdraw()).to.be.revertedWith(
        "No balance to withdraw"
      );

      // addr1 (deployer) should receive payout from the bet they still own (bet 1)
      const addr1InitialBalance = await ethers.provider.getBalance(
        addr1.address
      );
      const txWithdraw1 = await predMarket2.connect(addr1).withdraw();
      const receipt1 = await txWithdraw1.wait();
      const gasUsed1 = receipt1.gasUsed.mul(receipt1.effectiveGasPrice);
      const addr1FinalBalance = await ethers.provider.getBalance(addr1.address);
      const addr1BalanceChange = addr1FinalBalance
        .sub(addr1InitialBalance)
        .add(gasUsed1);

      // Expected payout for addr1 from bet 1 (they lost) should be zero
      // Expected payout from bet 2 (they are the deployer and owner)
      const totalPayout1 = betAmount.add(buyPrice);
      const creatorFee1 = totalPayout1.mul(2).div(100);
      const staffFee1 = totalPayout1.mul(3).div(100);
      const expectedPayout1 = totalPayout1.sub(creatorFee1).sub(staffFee1);
      expect(addr1BalanceChange).to.equal(expectedPayout1);
    });

    it("Only owner or staff can declare the winner", async function () {
      await createAndSellBet(addr1, 1);

      // Non-owner or non-staff tries to declare winner
      await expect(
        predMarket2.connect(addr1).declareWinner(1)
      ).to.be.revertedWith("Caller is not the owner or a staff member");

      // Owner declares winner
      await predMarket2.connect(owner).declareWinner(1);
    });

    it("Should prevent unauthorized users from unlisting bets", async function () {
      await createAndSellBet(addr1, 1);

      // addr2 tries to unlist addr1's bet
      await expect(
        predMarket2.connect(addr2).unlistBets([0])
      ).to.be.revertedWith("Caller is not the owner");
    });

    it("Should prevent buying a bet with incorrect price", async function () {
      await createAndSellBet(addr1, 1);

      // addr2 tries to buy the bet with incorrect price
      await expect(
        predMarket2
          .connect(addr2)
          .buyABet(0, { value: ethers.parseEther("0.1") })
      ).to.be.revertedWith("value sent is not correct");

      // Correct price purchase should succeed
      await expect(buyBet(addr2, 0)).not.to.be.reverted;
    });

    it("Should handle editing a deployed bet correctly", async function () {
      await createAndSellBet(addr1, 1);

      // addr1 edits their bet
      await predMarket2
        .connect(addr1)
        .editADeployedBet(0, betAmount, ethers.parseEther("0.6"), {
          value: ethers.parseEther("0"),
        });

      const bet = await predMarket2.arrayOfBets(0);
      expect(bet.amountToBuyFor).to.equal(ethers.parseEther("0.6"));
    });

    it("Should prevent users from withdrawing twice", async function () {
      await createAndSellBet(addr1, 1);
      await buyBet(addr2, 0);
      await predMarket2.connect(owner).declareWinner(1);
      await increaseTime(400);

      // addr2 withdraws
      await predMarket2.connect(addr2).withdraw();

      // addr2 tries to withdraw again
      await expect(predMarket2.connect(addr2).withdraw()).to.be.revertedWith(
        "No balance to withdraw"
      );
    });
  });

  describe("Testing Staff and Owner Functions", function () {
    it("Staff and Owner can transfer their respective amounts", async function () {
      await createAndSellBet(addr1, 1);
      await buyBet(addr2, 0);

      // Owner declares winner as 1
      await predMarket2.connect(owner).declareWinner(1);
      await increaseTime(400);

      // Participants withdraw
      await predMarket2.connect(addr2).withdraw();

      // Owner transfers owner amount
      const ownerInitialBalance = await ethers.provider.getBalance(
        owner.address
      );
      const txOwnerTransfer = await predMarket2
        .connect(owner)
        .transferOwnerAmount();
      const receiptOwner = await txOwnerTransfer.wait();
      const gasUsedOwner = receiptOwner.gasUsed.mul(
        receiptOwner.effectiveGasPrice
      );
      const ownerFinalBalance = await ethers.provider.getBalance(owner.address);
      const ownerBalanceChange = ownerFinalBalance
        .sub(ownerInitialBalance)
        .add(gasUsedOwner);

      // Owner should receive 2% of total payouts
      const totalPayout = betAmount.add(buyPrice);
      const expectedOwnerAmount = totalPayout.mul(2).div(100);
      expect(ownerBalanceChange).to.equal(expectedOwnerAmount);

      // Staff transfers staff amount
      const staffInitialBalance = await ethers.provider.getBalance(
        staff.address
      );
      const txStaffTransfer = await predMarket2
        .connect(staff)
        .transferStaffAmount();
      const receiptStaff = await txStaffTransfer.wait();
      const gasUsedStaff = receiptStaff.gasUsed.mul(
        receiptStaff.effectiveGasPrice
      );
      const staffFinalBalance = await ethers.provider.getBalance(staff.address);
      const staffBalanceChange = staffFinalBalance
        .sub(staffInitialBalance)
        .add(gasUsedStaff);

      // Staff should receive 3% of total payouts
      const expectedStaffAmount = totalPayout.mul(3).div(100);
      expect(staffBalanceChange).to.equal(expectedStaffAmount);
    });
  });
});
