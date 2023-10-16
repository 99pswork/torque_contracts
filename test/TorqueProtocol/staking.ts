import { time, loadFixture } from "@nomicfoundation/hardhat-network-helpers";
import { anyValue } from "@nomicfoundation/hardhat-chai-matchers/withArgs";
import { expect } from "chai";
import { ethers, network } from "hardhat";
import { BigNumber } from "ethers";

describe("Staking Contracts", function () {
  // We define a fixture to reuse the same setup in every test.
  // We use loadFixture to run this setup once, snapshot that state,
  // and reset Hardhat Network to that snapshot in every test.
  async function deployTokenAndStakingContract() {
    // Contracts are deployed using the first signer/account by default
    const [owner, alice, bob, daniel] = await ethers.getSigners();

    const TokenContract = await ethers.getContractFactory("Torque");
    const tokenContract = await TokenContract.deploy("Torque", "TORQ");

    const STorqueTokenContract = await ethers.getContractFactory(
      "StakingTorque"
    );
    const sTorqueTokenContract = await STorqueTokenContract.deploy();

    const StakingContract = await ethers.getContractFactory("Staking");
    const stakingContract = await StakingContract.deploy(
      tokenContract.address,
      sTorqueTokenContract.address
    );

    await stakingContract.setEnabled(true);
    await sTorqueTokenContract.grantMintRole(stakingContract.address);
    await sTorqueTokenContract.grantBurnRole(stakingContract.address);

    return {
      owner,
      alice,
      bob,
      daniel,
      tokenContract,
      sTorqueTokenContract,
      stakingContract,
    };
  }

  describe("Test STAKING", function () {
    it("Stake successfully", async function () {
      const stakeAmount = ethers.utils.parseEther("1000");

      const {
        owner,
        alice,
        bob,
        daniel,
        tokenContract,
        sTorqueTokenContract,
        stakingContract,
      } = await loadFixture(deployTokenAndStakingContract);

      await tokenContract.approve(stakingContract.address, stakeAmount);
      await stakingContract.deposit(stakeAmount);

      const balance = await tokenContract.balanceOf(stakingContract.address);
      const sTorqueBalance = await sTorqueTokenContract.balanceOf(
        owner.address
      );
      expect(balance).is.equal(ethers.utils.parseEther("1000"));
      expect(sTorqueBalance).is.equal(ethers.utils.parseEther("1000"));
    });

    it("Check reward after stake successfully", async function () {
      const {
        owner,
        alice,
        bob,
        daniel,
        tokenContract,
        sTorqueTokenContract,
        stakingContract,
      } = await loadFixture(deployTokenAndStakingContract);

      const period = 8640000; // 100 days

      await tokenContract.approve(
        stakingContract.address,
        ethers.utils.parseEther("1000")
      );

      await stakingContract.deposit(ethers.utils.parseEther("1000"));

      await network.provider.send("evm_increaseTime", [period]);
      await network.provider.send("evm_mine"); // this one will have 02:00 PM as its timestamp

      const reward = await stakingContract.getInterest(owner.address);
      expect(reward).is.approximately(
        "87671200000000000000",
        "1000000000000000"
      );
    });

    it("Unstake successfully", async function () {
      const {
        owner,
        alice,
        bob,
        daniel,
        tokenContract,
        sTorqueTokenContract,
        stakingContract,
      } = await loadFixture(deployTokenAndStakingContract);

      const period = 8640000; // 100 days
      const stakeAmount = ethers.utils.parseEther("1000");
      const initialTokenBalance = ethers.utils.parseEther("1000000");
      const contractRewardTreasury = ethers.utils.parseEther("500000");

      await tokenContract.approve(stakingContract.address, stakeAmount);
      await stakingContract.deposit(stakeAmount);

      await network.provider.send("evm_increaseTime", [period]);
      await network.provider.send("evm_mine"); // this one will have 02:00 PM as its timestamp
      // transfer treasury token
      await tokenContract.transfer(
        stakingContract.address,
        contractRewardTreasury
      );
      // approve sTorque
      await sTorqueTokenContract.approve(stakingContract.address, stakeAmount);

      // redeem
      await stakingContract.redeem(stakeAmount);
      const tokenAfterRedeem = await tokenContract.balanceOf(owner.address);
      const interestFee = BigNumber.from("87671200000000000000");

      expect(tokenAfterRedeem).is.approximately(
        initialTokenBalance.sub(contractRewardTreasury).add(interestFee),
        "1000000000000000"
      );
    });

    it("Stake multi time successfully", async function () {
      const {
        owner,
        alice,
        bob,
        daniel,
        tokenContract,
        sTorqueTokenContract,
        stakingContract,
      } = await loadFixture(deployTokenAndStakingContract);

      const period = 8640000; // 100 days
      const stakeAmount = ethers.utils.parseEther("1000");
      const initialTokenBalance = ethers.utils.parseEther("1000000");
      const contractRewardTreasury = ethers.utils.parseEther("500000");

      await tokenContract.approve(stakingContract.address, stakeAmount.div(2));
      await stakingContract.deposit(stakeAmount.div(2));

      await network.provider.send("evm_increaseTime", [period]);
      await network.provider.send("evm_mine"); // this one will have 02:00 PM as its timestamp

      await tokenContract.approve(stakingContract.address, stakeAmount.div(2));
      await stakingContract.deposit(stakeAmount.div(2));

      await network.provider.send("evm_increaseTime", [period]);
      await network.provider.send("evm_mine"); // this one will have 02:00 PM as its timestamp
      // transfer treasury token
      await tokenContract.transfer(
        stakingContract.address,
        contractRewardTreasury
      );
      // approve sTorque
      await sTorqueTokenContract.approve(stakingContract.address, stakeAmount);

      // redeem
      await stakingContract.redeem(stakeAmount);
      const tokenAfterRedeem = await tokenContract.balanceOf(owner.address);
      const interestFee = BigNumber.from("87671200000000000000");

      expect(tokenAfterRedeem).is.approximately(
        initialTokenBalance.sub(contractRewardTreasury).add(interestFee),
        "1000000000000000"
      );
    });

    it("Stake multi time with exact reward successfully", async function () {
      const {
        owner,
        alice,
        bob,
        daniel,
        tokenContract,
        sTorqueTokenContract,
        stakingContract,
      } = await loadFixture(deployTokenAndStakingContract);

      const period = 8640000; // 100 days
      const stakeAmount = ethers.utils.parseEther("1000");
      const initialTokenBalance = ethers.utils.parseEther("1000000");
      const contractRewardTreasury = ethers.utils.parseEther("500000");

      await tokenContract.approve(stakingContract.address, stakeAmount.div(2));
      await stakingContract.deposit(stakeAmount.div(2));

      await network.provider.send("evm_increaseTime", [period]);
      await network.provider.send("evm_mine"); // this one will have 02:00 PM as its timestamp

      await tokenContract.approve(stakingContract.address, stakeAmount.div(2));
      await stakingContract.deposit(stakeAmount.div(2));

      await network.provider.send("evm_increaseTime", [period]);
      await network.provider.send("evm_mine"); // this one will have 02:00 PM as its timestamp
      // transfer treasury token
      await tokenContract.transfer(
        stakingContract.address,
        contractRewardTreasury
      );
      // approve sTorque
      await sTorqueTokenContract.approve(stakingContract.address, stakeAmount);

      // redeem
      await stakingContract.redeem(stakeAmount);
      const tokenAfterRedeem = await tokenContract.balanceOf(owner.address);
      const interestFee = BigNumber.from("87671200000000000000");

      expect(tokenAfterRedeem).is.approximately(
        initialTokenBalance.sub(contractRewardTreasury).add(interestFee),
        "1000000000000000"
      );
    });

    it("Stake multi time and update timestamp successfully", async function () {});

    it("Stake multi time and update reward successfully", async function () {});

    it("Redeem reward and token successfully", async function () {});

    it("Change APR successfully", async function () {
      const {
        owner,
        alice,
        bob,
        daniel,
        tokenContract,
        sTorqueTokenContract,
        stakingContract,
      } = await loadFixture(deployTokenAndStakingContract);

      await stakingContract.updateAPR(1600);

      const period = 8640000; // 100 days
      const stakeAmount = ethers.utils.parseEther("1000");
      const initialTokenBalance = ethers.utils.parseEther("1000000");
      const contractRewardTreasury = ethers.utils.parseEther("500000");

      await tokenContract.approve(stakingContract.address, stakeAmount.div(2));
      await stakingContract.deposit(stakeAmount.div(2));

      await network.provider.send("evm_increaseTime", [period]);
      await network.provider.send("evm_mine"); // this one will have 02:00 PM as its timestamp

      await tokenContract.approve(stakingContract.address, stakeAmount.div(2));
      await stakingContract.deposit(stakeAmount.div(2));

      await network.provider.send("evm_increaseTime", [period]);
      await network.provider.send("evm_mine"); // this one will have 02:00 PM as its timestamp
      // transfer treasury token
      await tokenContract.transfer(
        stakingContract.address,
        contractRewardTreasury
      );
      // approve sTorque
      await sTorqueTokenContract.approve(stakingContract.address, stakeAmount);

      // redeem
      await stakingContract.redeem(stakeAmount);
      const tokenAfterRedeem = await tokenContract.balanceOf(owner.address);
      const interestFee = BigNumber.from("47671200000000000000");

      expect(tokenAfterRedeem).is.approximately(
        initialTokenBalance.sub(contractRewardTreasury).add(interestFee),
        "100000000000000000000"
      );
    });

    it("Change APR and check reward again successfully", async function () {});

    it("Further test cases...", async function () {});
  });
});
