pragma solidity ^0.4.0;

contract Arbitrated {
    /** @dev Should be raised before starting a dispute to provide context.  
     *  @param _disputeID ID of the dispute.
     *  @param _evidenceJSON A URI to the evidence JSON file whose name should be its keccak256 hash followed by .json.
     */
    event ContextEvidence(uint256 indexed _disputeID, string _evidenceJSON);

    /** @dev Give a ruling for a dispute. Must be called by the arbitration contract.
     *  @param _disputeID ID of the dispute.
     *  @param _ruling Ruling given by the arbitration contract. Note that 0 is reserved for "Not able/wanting to make a decision".
     */
    function rule(uint256 _disputeID, uint32 _ruling) public;
}