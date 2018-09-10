pragma solidity ^0.4.0;
import "./AppealableArbitrationService.sol";

contract CentralizedAppealableArbitrationService is AppealableArbitrationService {
    /* Contract owner. */
    address public owner = msg.sender;

    /* Arbitration fee. */
    uint256 private arbitrationFee;

    /* Disputes tracked by this arbitration contract.  Keyed off Arbitrable contract address and dispute ID. */    
    mapping(address => mapping(uint256 => DisputeStruct)) public disputesMap;

    /* Dispute struct for two parties with trusted mediator. */
    struct DisputeStruct {
        address[] parties;
        uint256 choices;
        uint256 ruling;
        DisputeStatus status;
        uint256 fee;
        uint256 appealTimeout;
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
    function setArbitrationFee(uint256 _fee) public {
        require(msg.sender == owner, "Only owner can call this function."); 
        arbitrationFee = _fee;
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
        return arbitrationFee;
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

        require(
            msg.value == arbitrationFee,
            "Must pay arbitration fee up front."
        );

        require(
            _parties.length > 0 && _parties.length <= 10,
            "Must include at least one party and at most 10 parties."
        );

        disputesMap[msg.sender][_disputeID] = DisputeStruct(
            _parties, 
            _choices, 
            0, 
            DisputeStatus.Waiting,
            msg.value,
            0
        );

        emit DisputeCreated(Arbitrated(msg.sender), _disputeID, false);
        emit ArbitrationFeesPaid(Arbitrated(msg.sender), _disputeID);
    }

    /** @dev Give an appealable ruling by owner.
     *  @param _arbitrated The contract which created the dispute.
     *  @param _disputeID ID of the dispute to rule.
     *  @param _ruling Ruling given by the arbitration contract. Note that 0 means "Not able/wanting to make a decision".
     */
    function giveAppealableRuling(Arbitrated _arbitrated, uint256 _disputeID, uint32 _ruling) public {
        DisputeStruct storage dispute = disputesMap[_arbitrated][_disputeID];

        require(
            msg.sender == owner, 
            "Only owner can call this function."
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
        dispute.status = DisputeStatus.Appealable;
        dispute.appealTimeout = block.timestamp + (7 days);

        emit Ruling(_arbitrated, _disputeID, _ruling, true);
    }

    /** @dev Give a final ruling by owner. UNTRUSTED.
     *  @param _arbitrated The contract which created the dispute.
     *  @param _disputeID ID of the dispute to rule.
     *  @param _ruling Ruling given by the arbitration contract. Note that 0 means "Not able/wanting to make a decision".
     */
    function giveFinalRuling(Arbitrated _arbitrated, uint256 _disputeID, uint32 _ruling) public {
        DisputeStruct storage dispute = disputesMap[_arbitrated][_disputeID];

        require(
            msg.sender == owner, 
            "Only owner can call this function."
        );

        require(
            _ruling > 0 && _ruling <= dispute.choices, 
            "Ruling must not be 0 and less than or equal to choices"
        );

        require(
            dispute.status == DisputeStatus.Waiting || 
            (
                dispute.status == DisputeStatus.Appealable && 
                block.timestamp > dispute.appealTimeout && 
                dispute.ruling == _ruling
            ),
            "Can only rule if waiting for ruling, or appeal timeout."
        );

        dispute.ruling = _ruling;
        dispute.status = DisputeStatus.Solved;

        msg.sender.transfer(dispute.fee);
        
        /* DANGEROUS external call.  Issue ruling to arbitrated contract. */
        _arbitrated.rule(_disputeID, _ruling);

        emit Ruling(_arbitrated, _disputeID, _ruling, false);
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

        bool senderIsParticipant = false;
        uint len = dispute.parties.length;
        for (uint i = 0; i < len; i++) {
            if (msg.sender == dispute.parties[i]) {
                senderIsParticipant = true;
            }
        }

        require(
            senderIsParticipant, 
            "Sender must be participant in dispute."
        );

        require(
            dispute.status != DisputeStatus.Solved,
            "Cannot submit evidence with current status."
        );

        emit Evidence(_arbitrated, _disputeID, msg.sender, _evidenceJSON);
    }

    /** @dev Determine whether ruling can be appealed, the cost of appeal and last timestamp of appeal.
     *  @param _arbitrated The contract which created the dispute.
     *  @param _disputeID ID of the dispute to be appealed.
     *  @return appealable Whether ruling can be appealed.
     *  @return fee Amount to be paid.
     *  @return untilTimestamp Timestamp until which appeal is possible.
     */
    function appealInfo(Arbitrated _arbitrated, uint256 _disputeID) public view returns(bool appealable, uint256 fee, uint256 untilTimestamp) {
        DisputeStruct storage dispute = disputesMap[_arbitrated][_disputeID];
        return (dispute.status == DisputeStatus.Appealable, arbitrationFee, dispute.appealTimeout);
    }

    /** @dev Appeal a ruling. Note that it has to be called before the arbitration contract calls rule.
     *  @param _arbitrated The contract which created the dispute.
     *  @param _disputeID ID of the dispute to be appealed.
     */
    function startAppeal(Arbitrated _arbitrated, uint256 _disputeID) public payable {
        DisputeStruct storage dispute = disputesMap[_arbitrated][_disputeID];

        require(
            msg.value == arbitrationFee,
            "Must pay fee for appeal"
        );

        require(
            dispute.status == DisputeStatus.Appealable && block.timestamp <= dispute.appealTimeout,
            "Must appeal before timeout."
        );

        dispute.fee += msg.value;
        dispute.status == DisputeStatus.Waiting;
    }
}