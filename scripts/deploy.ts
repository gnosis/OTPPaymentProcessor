import { task, types } from "hardhat/config";

task("deploy-otp-payment-processor", "deploy otp payment processor contract")
    .addParam("owner", "OTP Payment processor owner Multisig", undefined, types.string, true)
    .addParam("processor", "Processor Hot Wallet that will be securely used from Payments Oracle", undefined, types.string, true)
    .addParam("recipient", "FundsForwarder Multisig", undefined, types.string, true)
    .addParam("gaslimit", "Threshold that should be used", 200000, types.int, true)
    .addParam("gasprice", "Threshold that should be used", undefined, types.int, true)
    .setAction(async (taskArgs, hre) => {

      if (!taskArgs.owner) {
        throw new Error('owner must be procided');
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