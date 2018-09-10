pragma solidity ^0.4.0;
import "./Arbitrated.sol";

contract ArbitrationService {
    /* Enum with status of a dispute in arbitration process. */
    enum DisputeStatus { FeesOwed, Waiting, Appealable, Solved }

    /** @dev To be raised when a dispute is created.
     *  @param _arbitrated The contract which created the dispute.
     *  @param _disputeID ID of the dispute.
     *  @param _feesOwed Whether fees are still owed before starting arbitration.
     */
    event DisputeCreated(Arbitrated indexed _arbitrated, uint256 indexed _disputeID, bool _feesOwed);

    /** @dev To be raised when all arbitration fees are paid in full.
     *  @param _arbitrated The contract which created the dispute.
     *  @param _disputeID ID of the dispute.
     */
    event ArbitrationFeesPaid(Arbitrated indexed _arbitrated, uint256 indexed _disputeID);

    /** @dev To be raised when a ruling is given.
     *  @param _arbitrated The contract which created the dispute.
     *  @param _disputeID ID of the dispute.
     *  @param _ruling The ruling which was given.
     *  @param _appealable Whether appeal is possible.
     */
    event Ruling(Arbitrated indexed _arbitrated, uint256 indexed _disputeID, uint32 _ruling, bool _appealable);

    /** @dev To be raised when evidence are submitted. Should point to the resource (evidences are not to be stored on chain due to gas considerations).
     *  @param _arbitrated The contract which created the dispute.
     *  @param _disputeID ID of the dispute.
     *  @param _party The address of the party submiting the evidence. Note that 0x0 refers to evidence not submitted by any party.
     *  @param _evidenceJSON A URI to the evidence JSON file whose name should be its keccak256 hash followed by .json.
     */
    event Evidence(Arbitrated indexed _arbitrated, uint256 indexed _disputeID, address _party, string _evidenceJSON);

    /** @dev Upfront cost of arbitration that needs to be paid when creating dispute.  Recommended not to change this often.
     *  Can be 0 since Arbitrator contract may also ask parties to pay additional fees.
     *  @param _disputeID ID to track dispute given by the arbitrable contract.
     *  @param _choices Amount of choices the arbitration contract can make in this dispute. When ruling ruling<=choices.
     *  @param _parties Participants in the dispute.  Can be parties with an interest in the ruling, or mediators.
     *  @param _extraData Can be used to give additional info on the dispute to be created.
     *  @return fee Amount to be paid.
     */
    function upfrontCost(uint256 _disputeID, uint32 _choices, address[] _parties, uint256[] _extraData) public view returns(uint256 fee);
    
    /** @dev Create a dispute. Must be called by the arbitrable contract.
     *  Must be paid at least upfrontCost().
     *  @param _disputeID ID to track dispute given by the arbitrable contract.
     *  @param _choices Amount of choices the arbitration contract can make in this dispute. When ruling ruling<=choices.
     *  @param _parties Participants in the dispute.  Can be parties with an interest in the ruling, or mediators.
     *  @param _extraData Can be used to give additional info on the dispute to be created.
     */
    function createDispute(uint256 _disputeID, uint32 _choices, address[] _parties, uint256[] _extraData) public payable;

    /** @dev Return the status and ruling of a dispute.
     *  @param _arbitrated The contract which created the dispute.
     *  @param _disputeID ID of the dispute.
     *  @return status The status of the dispute.
     *  @return ruling The ruling which would or has been given.
     */
    function disputeStatus(Arbitrated _arbitrated, uint256 _disputeID) public view returns(DisputeStatus status, uint256 ruling);
}
