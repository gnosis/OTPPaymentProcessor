// SPDX-License-Identifier: LGPL-3.0-only

/// @title TangemPaymentProcessor -- A contract which allows a given payment processor to process user-authorized ERC20 token transfers.

/*  
This is the simplest possible implementation for a single user:
processor is only involved in processing of transactions coming from Visa,
no protection against double-spending,
gas is not taken into consideration!

In the multi-user scenario, a separate set of all variables should be stored for each user through MAPPING to the user's ‘card’ wallet address.
The user shall APPROVE this contract as a SPENDER from the host ERC20 contract.
*/

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

pragma solidity >=0.7.0 <0.9.0;

contract TangemTokenWallet {
    uint16 public otpRootCounter;
    bytes16 public otpRoot;
    uint256 public spendLimit;
    address card; // mapping to this address in the multi-user scenario
    address processor; // in this simple implementation: same for all users, cannot be updated once the contract is deployed
    ERC20 token;

    // Only callable by card
    error OnlyCard(address card, address sender);

    // Only callable by processor
    error OnlyProcessor(address processor, address sender);

    // Amount exceeds spend limit
    error ExceedsSpendLimit(uint256 limit, uint256 amount);

    // Invalid counter
    error InvalidCounter(uint256 optRootCounter, uint256 counter);

    // Invalid OTP
    error InvalidOtp(bytes16 otp);

    // Transfer Failed
    error TransferFailed();

    modifier onlyCard() {
        if (msg.sender != card) revert OnlyCard(card, msg.sender);
        _;
    }

    modifier onlyProcessor() {
        if (msg.sender != processor)
            revert OnlyProcessor(processor, msg.sender);
        _;
    }

    constructor(
        address _card,
        address _processor,
        address _token,
        uint256 _spendLimit
    ) {
        card = _card;
        processor = _processor;
        token = ERC20(_token);
        spendLimit = _spendLimit;
    }

    // Sync OTP between the card wallet and the applet (to be called at least once in the beginning)
    function initOTP(bytes16 otp, uint16 counter) external onlyCard {
        otpRoot = otp;
        otpRootCounter = counter;
    }

    // Collecting funds from Visa payments
    function process(
        uint256 tokenAmount,
        bytes16 otp,
        uint16 counter
    ) external onlyProcessor {
        if (tokenAmount > spendLimit)
            revert ExceedsSpendLimit(spendLimit, tokenAmount);

        if (otpRootCounter < counter)
            revert InvalidCounter(otpRootCounter, counter);

        // Authorization - OTP received from the card in the Visa tx is verified against the next OTP in the smart-contract
        bytes20 bAddress = bytes20(card);
        bytes16 bOTP = otp;
        uint16 c = counter;
        while (c < otpRootCounter) {
            bOTP = bytes16(sha256(bytes.concat(bAddress, bytes2(c), bOTP)));
            c++;
        }
        if (bOTP != otpRoot) revert InvalidOtp(bOTP);
        otpRootCounter = counter;
        otpRoot = otp;
        bool success = token.transferFrom(card, processor, tokenAmount);
        if (!success) revert TransferFailed();
    }

    // User sets the max amount of a single tx that can be approved by the processor in the PROCESS method (above)

    function changeSpendLimit(uint256 _spendLimit) external onlyCard {
        spendLimit = _spendLimit;
    }
}
