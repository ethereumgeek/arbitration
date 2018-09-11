pragma solidity ^0.4.0;
import "./Arbitrated.sol";
import "./ArbitrationService.sol";

contract TransactionManager is Arbitrated {

    /* Arbitration contract. */
    ArbitrationService public arbitrationService;

    /* Array of transactions. */
    TransactionData[] public transactionArray;

    /* Status of transaction. */
    enum TransactionStatus { 
        Pending, Disputed, PayReceiver, RefundSender, Closed, PreventReentrancy 
    }

    /* Transaction struct for a mediated payment. */
    struct TransactionData {
        TransactionStatus status;
        address sender;
        address receiver;
        address trustedMediator;
        uint256 amount;
        uint256 lockTimestamp;
    }

    /* Constructor. */
    constructor(ArbitrationService _arbitrationService) public {
        arbitrationService = _arbitrationService;
    }

    /* Fallback function. Added so ether sent to this contract is reverted. */
    function() public payable {
        revert("Invalid call to contract.");
    }

    /** @dev Creates a new transaction.
     *  @param _receiver Address receiving the payment.
     *  @param _trustedMediator Address mediating any potential disputes.
     *  @param _transactionTermsJSON A URI to the evidence JSON file whose name should be its keccak256 hash followed by .json.
     *  @param _lockTimestamp Timestamp when funds are locked until.
     */
    function newTransaction(
        address _receiver, 
        address _trustedMediator, 
        string _transactionTermsJSON,
        uint256 _lockTimestamp
    )
        public
        payable 
        returns(uint256) 
    {
        uint256 transactionId = transactionArray.push(TransactionData(
            TransactionStatus.Pending, 
            msg.sender, 
            _receiver, 
            _trustedMediator, 
            msg.value,
            _lockTimestamp
        )) - 1;

        emit ContextEvidence(transactionId, _transactionTermsJSON);
        return transactionId;
    }

    /** @dev Start dispute regarding transaction.
     *  @param _transactionId ID of the transaction.
     */
    function disputeTransaction(uint256 _transactionId) public payable {
        TransactionData storage transaction = transactionArray[_transactionId];

        require(
            msg.sender == transaction.sender || msg.sender == transaction.receiver, 
            "Only participants in transaction can start dispute."
        );

        require(
            transaction.status == TransactionStatus.Pending,
            "Only pending transactions can be disputed"
        );

        /* Change transaction status to prevent reentrancy attacks. */
        transaction.status = TransactionStatus.PreventReentrancy;

        address[] memory parties = new address[](3);
        parties[0] = transaction.sender;
        parties[1] = transaction.receiver;
        parties[2] = transaction.trustedMediator;

        uint256[] memory extraData;
        /* DANGEROUS external call.  Create dispute with arbitration. */
        arbitrationService.createDispute.value(msg.value)(_transactionId, 2, parties, extraData);
        
        /* Now we can change transaction status to disputed. */
        transaction.status = TransactionStatus.Disputed;
    }

    /** @dev Give a ruling for a dispute. Must be called by the arbitration contract.
     *  @param _disputeID ID of the dispute.
     *  @param _ruling Ruling given by the arbitration contract. Note that 0 is reserved for "Not able/wanting to make a decision".
     */
    function rule(uint256 _disputeID, uint32 _ruling) public {
        TransactionData storage transaction = transactionArray[_disputeID];

        require(
            msg.sender == address(arbitrationService), 
            "Only arbitration contract can rule on dispute"
        );

        require(
            transaction.status == TransactionStatus.Disputed,
            "Only pending transactions can be disputed"
        );

        if (_ruling == 1) {
            transaction.status = TransactionStatus.PayReceiver;
        }
        else {
            transaction.status = TransactionStatus.RefundSender;
        }
    }

    /** @dev Withdraw funds from transaction.
     *  @param _transactionId ID of the transaction.
     */
    function withdraw(uint256 _transactionId) public {
        TransactionData storage transaction = transactionArray[_transactionId];

        require(
            (msg.sender == transaction.sender && transaction.status == TransactionStatus.RefundSender) ||
            (msg.sender == transaction.receiver && transaction.status == TransactionStatus.PayReceiver) ||
            (
                msg.sender == transaction.receiver && 
                block.timestamp > transaction.lockTimestamp && 
                transaction.status == TransactionStatus.Pending
            ), 
            "Withdraw only allowed after lockTimestamp, or after ruling of dispute."
        );

        transaction.status = TransactionStatus.Closed;
        msg.sender.transfer(transaction.amount);
    }

    /** @dev Get count of transactions. */
    function getTransactionCount() public view returns(uint256 count) {
        return transactionArray.length;
    }
}