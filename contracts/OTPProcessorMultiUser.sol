/// SPDX-License-Identifier: LGPL-3.0-only

//// @title TangemPaymentProcessor -- A contract which allows a given payment processor to process user-authorized ERC20 token transfers.

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

pragma solidity >=0.7.0 <0.9.0;

struct Card {
    /// @dev Current root OTP.
    bytes16 otpRoot;
    /// @dev Current root OTP counter.
    uint16 otpRootCounter;
    /// @dev Address which holds tokens.
    address wallet;
}

contract OTPProcessorMultiUser is Ownable {
    /// @dev Mapping of card addresses to card variables.
    mapping(address => Card) public cards;

    /// @dev Mapping of wallets to cards to tokens to spending limits.
    mapping(address => mapping(address => mapping(address => uint256)))
        public spendLimits;

    /// @dev Address which can process transactions.
    address public processor;

    /// @dev Address which receives tokens on processed payments.
    address public recipient;

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
    event SetSpendLimit(
        address wallet,
        address card,
        address token,
        uint256 spendLimit
    );
    /// event SetToken(address token);
    event SetWallet(address card, address wallet);

    /// Only callable by processor
    error OnlyProcessor(address processor, address sender);

    /// Amount exceeds spend limit
    error ExceedsSpendLimit(address card, uint256 limit, uint256 amount);

    /// Invalid counter
    error InvalidCounter(address card, uint256 optRootCounter, uint256 counter);

    /// Invalid OTP
    error InvalidOtp(address card, bytes16 otp);

    /// Transfer Failed
    error TransferFailed();

    modifier onlyProcessor() {
        if (msg.sender != processor)
            revert OnlyProcessor(processor, msg.sender);
        _;
    }

    constructor(address _owner, address _processor, address _recipient) {
        processor = _processor;
        recipient = _recipient;
        transferOwnership(_owner);
    }

    /// @dev Sets the OTP Root and counter.
    /// @param card Address of the card on which to set the otpRoot and counter.
    /// @param otpRoot bytes16 OTP code to be set as the root.
    /// @param otpRootCounter uint16 OTP Root Counter to be set as the root.
    function setOTPRoot(
        address card,
        bytes16 otpRoot,
        uint16 otpRootCounter
    ) private {
        cards[card].otpRoot = otpRoot;
        cards[card].otpRootCounter = otpRootCounter;
        emit SetOTPRoot(card, cards[card].otpRoot, cards[card].otpRootCounter);
    }

    /// @dev Sets the OPTRoot and Wallet for the calling account.
    /// @param wallet Account to set as the wallet associated with the calling account.
    /// @param _otpRoot OTPRoot to set for the calling account.
    /// @param _otpRootCounter OTPRoot counter to set for the calling account.
    function initCard(
        address wallet,
        bytes16 _otpRoot,
        uint16 _otpRootCounter
    ) external {
        setWallet(wallet);
        setOTPRoot(msg.sender, _otpRoot, _otpRootCounter);
    }

    /// @dev Sync OTP between the card and the applet.
    /// @param _otpRoot bytes16 OTP code to be set as the root.
    /// @param _otpRootCounter uint16 OTP Root Counter to be set as the root.
    /// @notice Must be called at least once to initialize the contract.
    /// @notice Can only be called by card.
    function initOTP(bytes16 _otpRoot, uint16 _otpRootCounter) external {
        setOTPRoot(msg.sender, _otpRoot, _otpRootCounter);
    }

    /// @dev Sets the wallet that a card will spend from.
    /// @param wallet The wallet a card will spend from.
    function setWallet(address wallet) public {
        cards[msg.sender].wallet = wallet;
        emit SetWallet(msg.sender, cards[msg.sender].wallet);
    }

    //// @dev Sets the maximum amount of tokens which can be transferred via process() in a single call.
    //// @param card Address of the card to set spending limit for.
    //// @param token Address of the token to set a spending limit for.
    //// @param spendLimit The maximum amount of tokens to be set.
    function setSpendLimit(
        address card,
        address token,
        uint256 spendLimit
    ) external {
        spendLimits[msg.sender][card][token] = spendLimit;
        emit SetSpendLimit(msg.sender, card, token, spendLimit);
    }

    /// @dev Sets the address that can call process()
    /// @param _processor Address _processor Address to set processor to.
    /// @notice Can only be called by owner.
    function setProcessor(address _processor) external onlyOwner {
        processor = _processor;
        emit SetProcessor(processor);
    }

    /// @dev Sets the address that should receive tokens when a transaction is processed.
    /// @param _recipient Address _recipient Address to set recipient to.
    /// @notice Can only be called by owner.
    function setRecipient(address _recipient) external onlyOwner {
        recipient = _recipient;
        emit SetRecipient(recipient);
    }

    /// @dev Processes VISA payment
    /// @param card Address of the card to process payment for.
    /// @param token Address of the token to be used for payment.
    /// @param tokenAmount Amount of tokens to be transferred.
    /// @param otp OTP code to authorize transfer.
    /// @param counter OTP counter to authorize transfer.
    /// @notice Can only be called by processor.
    function process(
        address card,
        address token,
        uint256 tokenAmount,
        bytes16 otp,
        uint16 counter
    ) external onlyProcessor {
        address wallet = cards[card].wallet;
        if (tokenAmount > spendLimits[wallet][card][token])
            revert ExceedsSpendLimit(
                card,
                spendLimits[wallet][card][token],
                tokenAmount
            );

        uint16 otpRootCounter = cards[card].otpRootCounter;
        if (otpRootCounter <= counter)
            revert InvalidCounter(card, otpRootCounter, counter);

        bytes16 _otp = otp;
        uint16 _counter = counter;
        /// Authorization
        /// OTP received from the card in the VISA tx is verified against the next OTP in the smart-contract.
        while (_counter < otpRootCounter) {
            _otp = bytes16(sha256(abi.encodePacked(card, _counter, _otp)));
            _counter++;
        }
        if (_otp != cards[card].otpRoot) revert InvalidOtp(card, otp);

        setOTPRoot(card, otp, counter);
        bool success = IERC20(token).transferFrom(
            wallet,
            recipient,
            tokenAmount
        );
        if (!success) revert TransferFailed();
        emit PaymentProcessed(card, wallet, tokenAmount, otp, counter);
    }
}
