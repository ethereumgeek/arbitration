pragma solidity ^0.4.0;
import "./ArbitrationService.sol";

contract TwoPartyRulingRequestArbitrationService is ArbitrationService {
    /* Contract owner. */
    address public owner = msg.sender;

    /* Default arbitration fee. */
    uint256 private defaultArbitrationFee = 50 finney;

    /* Time to pay fee. */
    uint256 public timeToPayFee = 7 days;

    /* Mapping custom arbitration fee by mediator. */
    mapping(address => uint256) internal customArbitrationFeeMap;

    /* Mapping no arbitration fee by mediator. */
    mapping(address => bool) internal noArbitrationFeeMap;

    /* Disputes tracked by this arbitration contract.  Keyed off Arbitrable contract address and dispute ID. */    
    mapping(address => mapping(uint256 => DisputeStruct)) public disputesMap;

    /* Dispute struct for two parties with trusted mediator. */
    struct DisputeStruct {
        address partyA;
        address partyB;
        address trustedMediator;
        bool partyAPaid;
        bool partyBPaid;
        bool payMediatorAfterSolved;
        uint32 choices;
        uint32 ruling;
        uint32 partyARequestedRuling;
        uint32 partyBRequestedRuling;
        DisputeStatus status;
        uint256 feePerParty;
        uint256 timeout;
    }

    /* Constructor. */
    constructor() public {
    }

    /* Fallback function. Added so ether sent to this contract is reverted. */
    function() public payable {
        revert("Invalid call to contract.");
    }
    
    /** @dev Set the default arbitration fee. Only callable by the owner.
     *  @param _fee Default amount to be paid for arbitration.
     */
    function setDefaultFee(uint256 _fee) public {
        require(msg.sender == owner, "Only owner can call this function."); 
        defaultArbitrationFee = _fee;
    }
    
    /** @dev Set the time to pay arbitration fee. Only callable by the owner.
     *  @param _time Time to pay arbitration fee after other party.
     */
    function setTimeToPayFee(uint256 _time) public {
        require(msg.sender == owner, "Only owner can call this function."); 
        timeToPayFee = _time;
    }

    /** @dev Set custom arbitration fee for a specific mediator.
     *  @param _fee Amount to be paid for arbitration.
     */
    function setCustomFee(uint256 _fee) public {
        customArbitrationFeeMap[msg.sender] = _fee;
        noArbitrationFeeMap[msg.sender] = (_fee == 0);
    }

    /** @dev Cost of arbitration charged by a mediator.
     *  @param _trustedMediator The trusted mediator
     *  @return fee Amount to be paid.
     */
    function arbitrationFeePerParty(address _trustedMediator) public view returns(uint256 fee) {
        /* Arbitration fee is split between two parties. */
        fee = customArbitrationFeeMap[_trustedMediator] / 2;

        if (fee == 0 && !noArbitrationFeeMap[_trustedMediator]) {
            fee = defaultArbitrationFee / 2;
        }

        return fee;
    }

    /** @dev Upfront cost of arbitration that needs to be paid when creating dispute.  Recommended not to change this often.
     *  Can be 0 since Arbitrator contract may also ask parties to pay additional fees.
     *  @param _disputeID ID to track dispute given by the arbitrable contract.
     *  @param _choices Amount of choices the arbitration contract can make in this dispute. When ruling ruling<=choices.
     *  @param _parties Participants in the dispute.  Can be parties with an interest in the ruling, or mediators.
     *  @param _extraData Can be used to give additional info on the dispute to be created.
     *  @return fee Amount to be paid.
     */
    function upfrontCost(uint256 _disputeID, uint32 _choices, address[] _parties, uint256[] _extraData) public view returns(uint256 fee) {
        return uint256(0);
    }

    /** @dev Returns fees owed by each party and fee payment timeout.
     *  @param _arbitrated The contract which created the dispute.
     *  @param _disputeID ID of the dispute.
     *  @return partyAOwes The amount owed by party A.
     *  @return partyBOwes The amount owed by party B.
     *  @return timeout Timestamp when one party can choose ruling if other party hasn't paid fees.
     */
    function getFeesOwed(Arbitrated _arbitrated, uint256 _disputeID) public view returns(uint256 partyAOwes, uint256 partyBOwes, uint256 timeout) {
        DisputeStruct storage dispute = disputesMap[_arbitrated][_disputeID];
        return (
            dispute.partyAPaid ? 0 : dispute.feePerParty,
            dispute.partyBPaid ? 0 : dispute.feePerParty,
            dispute.timeout
        );
    }

    /** @dev Pay arbitration fee owed for dispute mediation.
     *  @param _arbitrated The contract which created the dispute.
     *  @param _disputeID ID of the dispute.
     */
    function payFee(Arbitrated _arbitrated, uint256 _disputeID) public payable {
        DisputeStruct storage dispute = disputesMap[_arbitrated][_disputeID];

        require(
            (msg.sender == dispute.partyA && !dispute.partyAPaid && msg.value == dispute.feePerParty) || 
            (msg.sender == dispute.partyB && !dispute.partyBPaid && msg.value == dispute.feePerParty),
            "Must pay exact fee owed."
        );

        require(
            dispute.status == DisputeStatus.FeesOwed,
            "Can only pay fees if status is FeesOwed."
        );

        if (msg.sender == dispute.partyA) {
            dispute.partyAPaid = true;
        }
        else {
            dispute.partyBPaid = true;
        }

        dispute.timeout = block.timestamp + timeToPayFee;

        if (dispute.partyAPaid && dispute.partyBPaid) {
            dispute.status = DisputeStatus.Waiting;
            emit ArbitrationFeesPaid(_arbitrated, _disputeID);
        }
    }

    /** @dev Withdraw any fees remaining after dispute has ended.
     *  @param _arbitrated The contract which created the dispute.
     *  @param _disputeID ID of the dispute.
     */
    function withdrawFeeAfterSolved(Arbitrated _arbitrated, uint256 _disputeID) public {
        DisputeStruct storage dispute = disputesMap[_arbitrated][_disputeID];

        require(
            dispute.status == DisputeStatus.Solved,
            "Can only withdraw after dispute is solved."
        );

        require(
            (msg.sender == dispute.partyA && dispute.partyAPaid && !dispute.payMediatorAfterSolved) || 
            (msg.sender == dispute.partyB && dispute.partyBPaid && !dispute.payMediatorAfterSolved) || 
            (msg.sender == dispute.trustedMediator && dispute.payMediatorAfterSolved),
            "Must have fee balance to withdraw."
        );
        
        if (msg.sender == dispute.trustedMediator) {
            /* Transfer arbitration fee to mediator.  Each party pays half of the total arbitration fee. */
            dispute.payMediatorAfterSolved = false;
            msg.sender.transfer(dispute.feePerParty * 2);
        }
        else if (msg.sender == dispute.partyA) {
            dispute.partyAPaid = false;
            msg.sender.transfer(dispute.feePerParty);
        }
        else {
            dispute.partyBPaid = false;
            msg.sender.transfer(dispute.feePerParty);
        }
    }

    /** @dev Create a dispute. Must be called by the arbitrable contract.
     *  Must be paid at least upfrontCost().
     *  @param _disputeID ID to track dispute given by the arbitrable contract.
     *  @param _choices Amount of choices the arbitration contract can make in this dispute. When ruling ruling<=choices.
     *  @param _parties Participants in the dispute.  Can be parties with an interest in the ruling, or mediators.
     *  @param _extraData Can be used to give additional info on the dispute to be created.
     */
    function createDispute(uint256 _disputeID, uint32 _choices, address[] _parties, uint256[] _extraData) public payable {
        require(
            disputesMap[msg.sender][_disputeID].choices == 0, 
            "Dispute for id must not already exist."
        );

        require(
            _choices >= 2,
            "Must have at least two choices to arbitrate."
        );

        require(
            _parties[0] != address(0x0) && _parties[1] != address(0x0) && _parties[2] != address(0x0),
            "Parties cannot be null or missing."
        );
        
        /* Get fee charged by trusted mediator (where _parties[2] is address of mediator). */
        uint256 feePerParty = arbitrationFeePerParty(_parties[2]);

        disputesMap[msg.sender][_disputeID] = DisputeStruct(
            _parties[0], 
            _parties[1], 
            _parties[2], 
            feePerParty == 0, 
            feePerParty == 0, 
            false, 
            _choices, 
            0, 
            0, 
            0, 
            feePerParty == 0 ? DisputeStatus.Waiting : DisputeStatus.FeesOwed,
            feePerParty,
            0
        );

        emit DisputeCreated(Arbitrated(msg.sender), _disputeID, feePerParty != 0);

        if (feePerParty == 0) {
            emit ArbitrationFeesPaid(Arbitrated(msg.sender), _disputeID);
        }
    }

    /** @dev Give a ruling by trusted mediator. UNTRUSTED.
     *  @param _arbitrated The contract which created the dispute.
     *  @param _disputeID ID of the dispute to rule.
     *  @param _ruling Ruling given by the arbitration contract. Note that 0 means "Not able/wanting to make a decision".
     */
    function giveRuling(Arbitrated _arbitrated, uint256 _disputeID, uint32 _ruling) public {
        DisputeStruct storage dispute = disputesMap[_arbitrated][_disputeID];

        require(
            msg.sender == dispute.trustedMediator, 
            "Only trusted mediator can call this function."
        );

        require(
            _ruling > 0 && _ruling <= dispute.choices, 
            "Ruling must not be 0 and less than or equal to choices"
        );

        require(
            dispute.status == DisputeStatus.Waiting,
            "Can only rule if waiting for ruling."
        );

        dispute.ruling = _ruling;
        dispute.status = DisputeStatus.Solved;
        dispute.partyAPaid = false;
        dispute.partyBPaid = false;
        
        /* Transfer arbitration fee to mediator.  Each party pays half of the total arbitration fee. */
        msg.sender.transfer(dispute.feePerParty * 2);

        /* DANGEROUS external call.  Issue ruling to arbitrated contract. */
        _arbitrated.rule(_disputeID, _ruling);

        emit Ruling(_arbitrated, _disputeID, _ruling, false);
    }

    /** @dev Give a ruling due to non-payment of fees timeout. UNTRUSTED.
     *  @param _arbitrated The contract which created the dispute.
     *  @param _disputeID ID of the dispute to rule.
     *  @param _ruling Ruling given by the arbitration contract. Note that 0 means "Not able/wanting to make a decision".
     */
    function giveTimeoutRuling(Arbitrated _arbitrated, uint256 _disputeID, uint32 _ruling) public {
        DisputeStruct storage dispute = disputesMap[_arbitrated][_disputeID];

        require(
            _ruling > 0 && _ruling <= dispute.choices, 
            "Ruling must not be 0 and less than or equal to choices"
        );

        require(
            dispute.status == DisputeStatus.FeesOwed,
            "Can only have timeout ruling if fees owed."
        );

        require(
            dispute.timeout != 0 && block.timestamp > dispute.timeout,
            "Timestamp must be later than dispute timeout."
        );

        require(
            (msg.sender == dispute.partyA && dispute.partyAPaid && !dispute.partyBPaid) ||
            (msg.sender == dispute.partyB && dispute.partyBPaid && !dispute.partyAPaid),
            "Requires sender has paid fee and other party has not paid fee."
        );

        dispute.ruling = _ruling;
        dispute.status = DisputeStatus.Solved;
        dispute.partyAPaid = false;
        dispute.partyBPaid = false;

        /* Refund arbitration fee if there's a timeout. */
        msg.sender.transfer(dispute.feePerParty);

        /* DANGEROUS external call.  Issue ruling to arbitrated contract. */
        _arbitrated.rule(_disputeID, _ruling);

        emit Ruling(_arbitrated, _disputeID, _ruling, false);
    }

    /** @dev Request a ruling. UNTRUSTED. 
     *  @param _arbitrated The contract which created the dispute.
     *  @param _disputeID ID of the dispute to rule.
     *  @param _ruling Ruling given by the arbitration contract. Note that 0 means "Not able/wanting to make a decision".
     */
    function requestRuling(Arbitrated _arbitrated, uint256 _disputeID, uint32 _ruling) public {
        DisputeStruct storage dispute = disputesMap[_arbitrated][_disputeID];

        require(
            _ruling > 0 && _ruling <= dispute.choices, 
            "Ruling must not be 0 and less than or equal to choices"
        );

        require(
            dispute.status != DisputeStatus.Solved,
            "Can only request ruling if not solved."
        );

        require(
            msg.sender == dispute.partyA || msg.sender == dispute.partyB,
            "Sender must be party A or party B."
        );

        if (msg.sender == dispute.partyA) {
            dispute.partyARequestedRuling = _ruling;
        }
        else {
            dispute.partyBRequestedRuling = _ruling;
        }

        /* If both parties request same ruling then issues that ruling. */
        if (dispute.partyARequestedRuling == dispute.partyBRequestedRuling) {

            /* Still pay mediator if they still have time to rule. */
            if (
                dispute.status == DisputeStatus.Waiting && 
                block.timestamp <= dispute.timeout &&
                dispute.partyAPaid &&
                dispute.partyBPaid
            ) {
                dispute.payMediatorAfterSolved = true;
                dispute.partyAPaid = false;
                dispute.partyBPaid = false;
            }

            dispute.ruling = _ruling;
            dispute.status = DisputeStatus.Solved;
            
            /* DANGEROUS external call.  Issue ruling to arbitrated contract. */
            _arbitrated.rule(_disputeID, _ruling);
            emit Ruling(_arbitrated, _disputeID, _ruling, false);
        }
    }

    /** @dev Return the status and ruling of a dispute.
     *  @param _arbitrated The contract which created the dispute.
     *  @param _disputeID ID of the dispute.
     *  @return status The status of the dispute.
     *  @return ruling The ruling which would or has been given.
     */
    function disputeStatus(Arbitrated _arbitrated, uint256 _disputeID) public view returns(DisputeStatus status, uint256 ruling) {
        DisputeStruct storage dispute = disputesMap[_arbitrated][_disputeID];
        return (dispute.status, dispute.ruling);
    }

    /** @dev Submit a reference to evidence.  Generates an Evidence EVENT.
     *  @param _arbitrated The contract which created the dispute.
     *  @param _disputeID ID of the dispute.
     *  @param _evidenceJSON A URI to the evidence JSON file whose name should be its keccak256 hash followed by .json.
     */
    function submitEvidence(Arbitrated _arbitrated, uint256 _disputeID, string _evidenceJSON) public {
        DisputeStruct storage dispute = disputesMap[_arbitrated][_disputeID];

        require(
            msg.sender == dispute.partyA || 
            msg.sender == dispute.partyB, 
            "Sender must be party A or party B."
        );

        require(
            dispute.status != DisputeStatus.Solved,
            "Cannot submit evidence with current status."
        );

        emit Evidence(_arbitrated, _disputeID, msg.sender, _evidenceJSON);
    }
}