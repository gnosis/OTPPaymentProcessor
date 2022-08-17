// SPDX-License-Identifier: LGPL-3.0-only

/// @title TangemPaymentProcessor -- A contract which allows a given payment processor to process user-authorized ERC20 token transfers.

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

pragma solidity >=0.7.0 <0.9.0;

struct Card {
    // @dev Current root OTP.
    bytes16 otpRoot;
    // @dev Current root OTP counter.
    uint16 otpRootCounter;
    // @dev Address which holds tokens.
    address wallet;
}

contract OTPProcessorMultiUser is Ownable {
    // @dev Mapping of card addresses to card variables.
    mapping(address => Card) public cards;

    // @dev Mapping of wallets to cards to spending limits.
    mapping(address => mapping(address => uint256)) public spendingLimits;

    // @dev Address which can process transactions.
    address public processor;

    // @dev Address which receives tokens on processed payments.
    address public recipient;

    // @dev ERC20 token which can be transferred by processor.
    ERC20 public token;

    event PaymentProcessed(
        address card,
        address wallet,
        uint256 value,
        bytes16 otp,
        uint16 counter
    );
    event SetOTPRoot(address card, bytes16 otpRoot, uint16 otpRootCounter);
    event SetProcessor(address processor);
    event SetRecipient(address recipient);
    event SetSpendLimit(address wallet, address card, uint256 spendLimit);
    event SetToken(address token);
    event SetWallet(address card, address wallet);

    // Only callable by card
    error OnlyCard(address card, address sender);

    // Only callable by processor
    error OnlyProcessor(address processor, address sender);

    // Only callable by wallet
    error OnlyWallet(address wallet, address sender);

    // Amount exceeds spend limit
    error ExceedsSpendLimit(address card, uint256 limit, uint256 amount);

    // Invalid counter
    error InvalidCounter(address card, uint256 optRootCounter, uint256 counter);

    // Invalid OTP
    error InvalidOtp(address card, bytes16 otp);

    // Transfer Failed
    error TransferFailed();

    modifier onlyProcessor() {
        if (msg.sender != processor)
            revert OnlyProcessor(processor, msg.sender);
        _;
    }

    constructor(
        address _owner,
        address _processor,
        address _recipient,
        address _token
    ) {
        processor = _processor;
        recipient = _recipient;
        token = ERC20(_token);
        transferOwnership(_owner);
    }

    // @dev Sync OTP between the card and the applet.
    // @param _otpRoot bytes16 OTP code to be set as the root.
    // @param _otpRootCounter uint16 OTP Root Counter to be set as the root.
    // @notice Must be called at least once to initialize the contract.
    // @notice Can only be called by card.
    function initOTP(bytes16 _otpRoot, uint16 _otpRootCounter) external {
        setOTPRoot(msg.sender, _otpRoot, _otpRootCounter);
    }

    // @dev Processes VISA payment
    // @param tokenAmount Amount of tokens to be transferred.
    // @param otp OTP code to authorize transfer.
    // @param counter OTP counter to authorize transfer.
    // @notice Can only be called by processor.
    function process(
        address card,
        uint256 tokenAmount,
        bytes16 otp,
        uint16 counter
    ) external onlyProcessor {
        if (
            tokenAmount > spendingLimits[cards[card].wallet][card] &&
            card != cards[card].wallet
        )
            revert ExceedsSpendLimit(
                card,
                spendingLimits[cards[card].wallet][card],
                tokenAmount
            );

        if (cards[card].otpRootCounter < counter)
            revert InvalidCounter(card, cards[card].otpRootCounter, counter);

        // Authorization
        // OTP received from the card in the VISA tx is verified against the next OTP in the smart-contract.
        while (counter < cards[card].otpRootCounter) {
            otp = bytes16(sha256(abi.encodePacked(card, counter, otp)));
            counter++;
        }
        if (otp != cards[card].otpRoot) revert InvalidOtp(card, otp);

        setOTPRoot(card, otp, counter);
        bool success = token.transferFrom(
            cards[card].wallet,
            recipient,
            tokenAmount
        );
        if (!success) revert TransferFailed();
        emit PaymentProcessed(
            card,
            cards[card].wallet,
            tokenAmount,
            otp,
            counter
        );
    }

    // @dev Sets the OTP Root and counter.
    // @param card Address of the card on which to set the otpRoot and counter.
    // @param otpRoot bytes16 OTP code to be set as the root.
    // @param otpRootCounter uint16 OTP Root Counter to be set as the root.
    function setOTPRoot(
        address card,
        bytes16 otpRoot,
        uint16 otpRootCounter
    ) private {
        cards[card].otpRoot = otpRoot;
        cards[card].otpRootCounter = otpRootCounter;
        emit SetOTPRoot(card, cards[card].otpRoot, cards[card].otpRootCounter);
    }

    // @dev Sets the maximum amount of tokens which can be transferred via process() in a single call.
    // @param card Address of the card to set spending limit for.
    // @param spendLimit The maximum amount of tokens to be set.
    function setSpendLimit(address card, uint256 spendLimit) external {
        spendingLimits[msg.sender][card] = spendLimit;
        emit SetSpendLimit(msg.sender, card, spendingLimits[msg.sender][card]);
    }

    // @dev Sets the wallet that a card will spend from.
    // @param wallet The wallet a card will spend from.
    function setWallet(address wallet) external {
        cards[msg.sender].wallet = wallet;
        emit SetWallet(msg.sender, cards[msg.sender].wallet);
    }

    // @dev Sets the address that can call process()
    // @param Address _processor Address to set processor to.
    // @notice Can only be called by owner.
    function setProcessor(address _processor) external onlyOwner {
        processor = _processor;
        emit SetProcessor(processor);
    }

    // @dev Sets the address that should receive tokens when a transaction is processed.
    // @param Address _recipient Address to set recipient to.
    // @notice Can only be called by owner.
    function setRecipient(address _recipient) external onlyOwner {
        recipient = _recipient;
        emit SetRecipient(recipient);
    }

    // @dev Sets the token that should be transferred when transactions are processed.
    // @param Address _token Address to set token to.
    // @notice Can only be called by owner.
    function setToken(address _token) external onlyOwner {
        token = ERC20(_token);
        emit SetToken(address(token));
    }
}
