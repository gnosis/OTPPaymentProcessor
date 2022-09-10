import { ethers } from "hardhat";

async function main() {
  const owner = "0x53bcFaEd43441C7bB6149563eC11f756739C9f6A";
  const processor = "0xe4c4693526e4e3a26f36311d3f80a193b2bae906";
  const recipient = "0xaE56c5A8935210Acfc142832eCA3523b7d757b53";
  const token = "0x4346186e7461cB4DF06bCFCB4cD591423022e417";

  const OTPProcessor = await ethers.getContractFactory("OTPProcessorMultiUser");
  const otpProcessor = await OTPProcessor.deploy(
    owner,
    processor,
    recipient,
    token
  );

  await otpProcessor.deployed();
  const [signer] = await ethers.getSigners();
  console.log(
    "account:",
    signer.address,
    "\n-----------------",
    "\nOTPProcessorMultiUser:",
    otpProcessor.address,
    "\n-----------------",
    "\nowner:",
    await otpProcessor.owner(),
    "\nprocessor:",
    await otpProcessor.processor(),
    "\nrecipient:",
    await otpProcessor.recipient(),
    "\ntoken:",
    await otpProcessor.token(),
    "\n-----------------"
  );
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
