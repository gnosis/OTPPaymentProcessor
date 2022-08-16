/*  
This is the simplest possible implementation for a single user:
processor is only involved in processing of transactions coming from Visa,
no protection against double-spending,
gas is not taken into consideration!

In the multi-user scenario, a separate set of all variables should be stored for each user through MAPPING to the user's ‘card’ wallet address.
The user shall APPROVE this contract as a SPENDER from the host ERC20 contract.
*/

contract TangemTokenWallet {
    uint32 public sequence;
    uint16 public otpRootCounter;
    bytes16 public otpRoot;
    uint256 public spendLimit;
    address card; // mapping to this address in the multi-user scenario
    address processor; // in this simple implementation: same for all users, cannot be updated once the contract is deployed
    ERC20Interface tokenContract;

    constructor(
        address card_,
        address processor_,
        address contractAddress,
        uint256 spendLimit_
    ) {
        card = card_;
        processor = processor_;
        tokenContract = ERC20Interface(contractAddress);
        spendLimit = spendLimit_;
    }

    //  Sync OTP between the card wallet and the applet (to be called at least once in the beginning)

    function initOTP(bytes16 otp, uint16 counter) external {
        require(msg.sender == card, "Invalid sender!"); // signed by the user only
        otpRoot = otp;
        otpRootCounter = counter;
    }

    //  Collecting funds from Visa payments

    function process(
        uint256 tokenAmount,
        bytes16 otp,
        uint16 counter
    ) public {
        require(msg.sender == processor, "Invalid sender!");
        require(tokenAmount <= spendLimit, "Amount exceeds spend limit!");
        require(
            tokenAmount <= tokenContract.balanceOf(address(this)),
            "Insufficient balance!"
        );
        require(otpRootCounter > counter, "Invalid counter!");

        //  Authorization - OTP received from the card in the Visa tx is verified against the next OTP in the smart-contract

        bytes20 bAddress = bytes20(card);
        bytes16 bOTP = otp;
        uint16 c = counter;
        while (c < otpRootCounter) {
            bOTP = bytes16(sha256(bytes.concat(bAddress, bytes2(c), bOTP)));
            c++;
        }
        require(bOTP == otpRoot, "Invalid OTP!");
        otpRootCounter = counter;
        otpRoot = otp;
        require(
            tokenContract.transfer(processor, tokenAmount),
            "Transfer failed!"
        );
    }

    // User sets the max amount of a single tx that can be approved by the processor in the PROCESS method (above)

    function changeSpendLimit(uint256 spendLimit) external {
        require(msg.sender == card, "Invalid sender!");
        spendLimit = spendLimit_;
    }
}
