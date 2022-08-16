import { time, loadFixture } from "@nomicfoundation/hardhat-network-helpers";
import { anyValue } from "@nomicfoundation/hardhat-chai-matchers/withArgs";
import { expect } from "chai";
import hre, { ethers } from "hardhat";
import { OTPProcessor__factory } from "../typechain-types/factories/contracts/OTPProcessorSingleUser.sol";
import { BigNumber } from "ethers";
import { token } from "../typechain-types/@openzeppelin/contracts";

const otp999 = "0xc7992838b0198b59f472a1017044812e";
const otp998 = "0xee79e77077bf4f328fed0191c25088f7";
const otp995 = "0x287f3d79476b7571b4e269e1f2bc6d3c";
const spendLimit = ethers.utils.parseEther("100");
const bytes16zero = "0x00000000000000000000000000000000";

describe("OTPProcessorSingleUser", function () {
  async function setup() {
    const [wallet, processor] = await ethers.getSigners();
    await hre.network.provider.request({
      method: "hardhat_impersonateAccount",
      params: ["0x5C9b5c6313A3746A1246d07BbEDC0292DA99F8E2"],
    });
    const card = await ethers.getSigner(
      "0x5C9b5c6313A3746A1246d07BbEDC0292DA99F8E2"
    );
    await wallet.sendTransaction({
      to: card.address,
      value: ethers.utils.parseEther("1"),
    });

    const Token = await ethers.getContractFactory("TestToken");
    const token = await Token.deploy(18);
    await token.mint(wallet.address, ethers.utils.parseEther("300"));
    const OTPProcessor = await ethers.getContractFactory(
      "OTPProcessorSingleUser"
    );
    const otpProcessor = await OTPProcessor.deploy(
      card.address,
      wallet.address,
      processor.address,
      token.address,
      spendLimit
    );

    return { card, otpProcessor, processor, token, wallet };
  }

  describe("Deployment", function () {
    it("Should set the right card", async () => {
      const { card, otpProcessor } = await loadFixture(setup);

      expect(await otpProcessor.card()).to.equal(card.address);
    });

    it("Should set the right wallet", async () => {
      const { otpProcessor, wallet } = await loadFixture(setup);

      expect(await otpProcessor.wallet()).to.equal(wallet.address);
    });

    it("Should set the right processor", async () => {
      const { otpProcessor, processor } = await loadFixture(setup);

      expect(await otpProcessor.processor()).to.equal(processor.address);
    });

    it("Should set the right token", async () => {
      const { otpProcessor, token } = await loadFixture(setup);

      expect(await otpProcessor.token()).to.equal(token.address);
    });

    it("Should set the right spend limit", async () => {
      const { otpProcessor } = await loadFixture(setup);

      expect(await otpProcessor.spendLimit()).to.equal(spendLimit);
    });

    it("Should not have set otpRoot and otpRootCount", async () => {
      const { otpProcessor } = await loadFixture(setup);

      expect(await otpProcessor.otpRoot()).to.equal(bytes16zero);
      expect(await otpProcessor.otpRootCounter()).to.equal(0);
    });
  });

  describe("initOTP", function () {
    it("Should revert if caller is not card", async () => {
      const { card, otpProcessor, wallet } = await loadFixture(setup);

      expect(otpProcessor.initOTP(otp995, 995))
        .to.be.revertedWithCustomError(otpProcessor, "OnlyCard")
        .withArgs([card.address, wallet.address]);
    });

    it("Should set otpRoot and otpRootCounter", async () => {
      const { card, otpProcessor } = await loadFixture(setup);

      expect(await otpProcessor.connect(card).initOTP(otp995, 995));
      expect(await otpProcessor.otpRoot()).to.equal(otp995);
      expect(await otpProcessor.otpRootCounter()).to.equal(995);
    });

    it("Should emit SetOTPRoot() event", async () => {
      const { card, otpProcessor } = await loadFixture(setup);
      expect(await otpProcessor.connect(card).initOTP(otp995, 995))
        .to.emit(otpProcessor, "SetOTPRoot")
        .withArgs([otp995, 995]);
    });
  });

  describe("setSpendLimit()", function () {
    it("Should revert if caller is not card", async () => {
      const { card, otpProcessor, wallet } = await loadFixture(setup);

      expect(otpProcessor.setSpendLimit(spendLimit))
        .to.be.revertedWithCustomError(otpProcessor, "OnlyCard")
        .withArgs([card.address, wallet.address]);
    });

    it("Should set otpRoot and otpRootCounter", async () => {
      const { card, otpProcessor } = await loadFixture(setup);

      expect(await otpProcessor.connect(card).setSpendLimit(spendLimit));
      expect(await otpProcessor.spendLimit()).to.equal(spendLimit);
    });

    it("Should emit SetSpendLimit() event", async () => {
      const { card, otpProcessor } = await loadFixture(setup);

      expect(await otpProcessor.connect(card).setSpendLimit(spendLimit))
        .to.emit(otpProcessor, "SetSpendLimit")
        .withArgs([spendLimit]);
    });
  });

  describe("process()", function () {
    it("Should revert if caller is not processor", async () => {
      const { card, otpProcessor, processor, wallet } = await loadFixture(
        setup
      );

      expect(otpProcessor.process(spendLimit, otp998, 998))
        .to.be.revertedWithCustomError(otpProcessor, "OnlyProcessor")
        .withArgs(processor.address, wallet.address);
    });

    it("Should revert if amount is greater than spending limit", async () => {
      const { otpProcessor, processor } = await loadFixture(setup);
      const spend = spendLimit.add(BigNumber.from(1));

      expect(otpProcessor.connect(processor).process(spend, otp998, 998))
        .to.be.revertedWithCustomError(otpProcessor, "ExceedsSpendLimit")
        .withArgs(spendLimit, spend);
    });

    it("Should revert if otpRootCounter is less than counter", async () => {
      const { card, otpProcessor, processor, wallet } = await loadFixture(
        setup
      );

      expect(otpProcessor.connect(processor).process(spendLimit, otp998, 994))
        .to.be.revertedWithCustomError(otpProcessor, "InvalidCounter")
        .withArgs(998, 994);
    });

    it("Should revert if OTP is invalid", async () => {
      const { card, otpProcessor, processor, wallet } = await loadFixture(
        setup
      );
      const otpInvalid = "0xbad00000000000000000000000000dad";

      expect(
        otpProcessor.connect(processor).process(spendLimit, otpInvalid, 998)
      )
        .to.be.revertedWithCustomError(otpProcessor, "InvalidOtp")
        .withArgs(otpInvalid);
    });

    it("Should revert if token.transferFrom() fails", async () => {
      const { card, otpProcessor, processor } = await loadFixture(setup);

      expect(await otpProcessor.connect(card).initOTP(otp999, 999));
      expect(await otpProcessor.otpRoot()).to.equal(otp999);
      expect(await otpProcessor.otpRootCounter()).to.equal(999);
      expect(
        otpProcessor.connect(processor).process(spendLimit, otp998, 998)
      ).to.be.revertedWith("ERC20: insufficient allowance");
    });
    it("Should transfer correct amount of tokens from wallet to processor", async () => {
      const { card, otpProcessor, processor, token } = await loadFixture(setup);

      expect(await otpProcessor.connect(card).initOTP(otp999, 999));
      expect(await otpProcessor.otpRoot()).to.equal(otp999);
      expect(await otpProcessor.otpRootCounter()).to.equal(999);

      expect(await token.approve(otpProcessor.address, spendLimit));
      expect(
        await otpProcessor.connect(processor).process(spendLimit, otp998, 998)
      );
      expect(await token.balanceOf(processor.address)).to.equal(spendLimit);
    });
    it("Should emit PaymentProcessed() event", async () => {
      const { card, otpProcessor, processor, token } = await loadFixture(setup);

      expect(await otpProcessor.connect(card).initOTP(otp999, 999));
      expect(await otpProcessor.otpRoot()).to.equal(otp999);
      expect(await otpProcessor.otpRootCounter()).to.equal(999);

      expect(await token.approve(otpProcessor.address, spendLimit));
      expect(
        await otpProcessor.connect(processor).process(spendLimit, otp998, 998)
      )
        .to.emit(otpProcessor, "PaymentProcessed")
        .withArgs([spendLimit, otp998, 998]);
    });
  });
});
