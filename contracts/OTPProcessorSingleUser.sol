// SPDX-License-Identifier: LGPL-3.0-only

/// @title TangemPaymentProcessor -- A contract which allows a given payment processor to process user-authorized ERC20 token transfers.

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

pragma solidity >=0.7.0 <0.9.0;

contract OTPProcessorSingleUser {
    // @dev Address which can approve transfers.
    address public card;

    // @dev Current root OTP.
    bytes16 public otpRoot;

    // @dev Current root OTP counter.
    uint16 public otpRootCounter;

    // @dev Address which can process transactions.
    address public processor;

    // @dev Maximum amount of tokens that can be transferred per call.
    uint256 public spendLimit;

    // @dev Address which receives tokens on processed payments.
    address public recipient;

    // @dev Address which holds tokens.
    address public wallet;

    // @dev ERC20 token which can be transferred by processor.
    ERC20 public token;

    event SetOTPRoot(bytes16 otpRoot, uint16 otpRootCounter);
    event SetSpendLimit(uint256 spendLimit);
    event PaymentProcessed(uint256 value, bytes16 otp, uint16 counter);

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
        address _recipient,
        address _token,
        address _wallet,
        uint256 _spendLimit
    ) {
        card = _card;
        processor = _processor;
        recipient = _recipient;
        token = ERC20(_token);
        wallet = _wallet;
        spendLimit = _spendLimit;
    }

    // @dev Sync OTP between the card and the applet.
    // @param _otpRoot bytes16 OTP code to be set as the root.
    // @param _otpRootCounter uint16 OTP Root Counter to be set as the root.
    // @notice Must be called at least once to initialize the contract.
    // @notice Can only be called by card.
    function initOTP(bytes16 _otpRoot, uint16 _otpRootCounter)
        external
        onlyCard
    {
        setOTPRoot(_otpRoot, _otpRootCounter);
    }

    // @dev Processes VISA payment
    // @param tokenAmount Amount of tokens to be transferred.
    // @param otp OTP code to authorize transfer.
    // @param counter OTP counter to authorize transfer.
    // @notice Can only be called by processor.
    function process(
        uint256 tokenAmount,
        bytes16 otp,
        uint16 counter
    ) external onlyProcessor {
        if (tokenAmount > spendLimit)
            revert ExceedsSpendLimit(spendLimit, tokenAmount);

        if (otpRootCounter < counter)
            revert InvalidCounter(otpRootCounter, counter);

        // Authorization
        // OTP received from the card in the VISA tx is verified against the next OTP in the smart-contract.
        while (counter < otpRootCounter) {
            otp = bytes16(sha256(abi.encodePacked(card, counter, otp)));
            counter++;
        }
        if (otp != otpRoot) revert InvalidOtp(otp);

        setOTPRoot(otp, counter);
        bool success = token.transferFrom(wallet, recipient, tokenAmount);
        if (!success) revert TransferFailed();
        emit PaymentProcessed(tokenAmount, otp, counter);
    }

    // @dev Sets the OTP Root and counter.
    // @param _otpRoot bytes16 OTP code to be set as the root.
    // @param _otpRootCounter uint16 OTP Root Counter to be set as the root.
    function setOTPRoot(bytes16 _otpRoot, uint16 _otpRootCounter) private {
        otpRoot = _otpRoot;
        otpRootCounter = _otpRootCounter;
        emit SetOTPRoot(otpRoot, otpRootCounter);
    }

    // @dev Set the maximum amount of tokens which can be transferred via process() in a single call.
    // @param _spendLimit the maximum amount of tokens to be set.
    // @notice Can only be called by card.
    function setSpendLimit(uint256 _spendLimit) external onlyCard {
        spendLimit = _spendLimit;
        emit SetSpendLimit(spendLimit);
    }
}
