pragma solidity ^0.4.0;
import "./ArbitrationService.sol";

contract AppealableArbitrationService is ArbitrationService {
    /** @dev Determine whether ruling can be appealed, the cost of appeal and last timestamp of appeal.
     *  @param _arbitrated The contract which created the dispute.
     *  @param _disputeID ID of the dispute to be appealed.
     *  @return appealable Whether ruling can be appealed.
     *  @return fee Amount to be paid.
     *  @return untilTimestamp Timestamp until which appeal is possible.
     */    
    function appealInfo(Arbitrated _arbitrated, uint256 _disputeID) public view returns(bool appealable, uint256 fee, uint256 untilTimestamp);

    /** @dev Appeal a ruling. Note that it has to be called before the arbitration contract calls rule.
     *  @param _arbitrated The contract which created the dispute.
     *  @param _disputeID ID of the dispute to be appealed.
     */
    function startAppeal(Arbitrated _arbitrated, uint256 _disputeID) public payable;
}