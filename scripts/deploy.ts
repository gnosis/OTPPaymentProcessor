import { task, types } from "hardhat/config";

task("deploy-otp-payment-processor", "deploy otp payment processor contract")
    .addParam("owner", "OTP Payment processor owner address", undefined, types.string, true)
    .addParam("processor", "Processor that will trigger the contract", undefined, types.string, true)
    .addParam("recipient", "Recipient that should receive funds from the OTP Payment processor", undefined, types.string, true)
    .addParam("gaslimit", "Gas limit for the transaction", 200000, types.int, true)
    .addParam("gasprice", "Gas price for the transaction", undefined, types.int, true)
    .setAction(async (taskArgs, hre) => {

      if (!taskArgs.owner) {
        throw new Error('owner must be provided');
      }

      if (!taskArgs.processor) {
        throw new Error('processor must be provided');
      }

      if (!taskArgs.recipient) {
        throw new Error('recipient must be provided');
      }

      const OTPProcessor = await hre.ethers.getContractFactory("OTPProcessorMultiUser");
      const otpProcessor = await OTPProcessor.deploy(
        taskArgs.owner,
        taskArgs.processor,
        taskArgs.recipient,
      );

      await otpProcessor.deployed();
      const [signer] = await hre.ethers.getSigners();
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
        "\n-----------------"
      );
        
    });

export { }