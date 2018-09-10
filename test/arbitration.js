var TransactionManager = artifacts.require("TransactionManager");
var TwoPartyMediatedArbitrationService = artifacts.require("TwoPartyMediatedArbitrationService");

/* Returns event from transaction based on name. */
function getEventFromTransaction(tx, name) {
  for (let i = 0; i < tx.logs.length; i++) {
      if (tx.logs[i].event === name) {
          return tx.logs[i].args;
      }
  }
  return null;
}

/* Return unix time for given days from now. */
function unixDaysFromNow(days) {
    return Math.floor(new Date() / 1000) + (days * 24 * 3600);
}

contract('TransactionManager', function(accounts) {

    it("Test transaction with refund", async function() {

        /* Transaction manager and arbitration service instances. */
        let transactionManagerInstance = await TransactionManager.deployed();
        let arbitrationServiceAddress = await transactionManagerInstance.arbitrationService();
        let arbitrationServiceInstance = await TwoPartyMediatedArbitrationService.at(arbitrationServiceAddress);
        
        /* Initial balance of party A. */
        let partyAInitialBalance = await web3.eth.getBalance(accounts[0]);

        /* Send transaction to party B. */
        let tx = await transactionManagerInstance.newTransaction(
          accounts[1],
          accounts[2],
          "https://arbpay.app/5520AB7823EB3E231AB96DB95CF39BF3D28952D45B76D8CD71D8C7283CA12156.json",
          unixDaysFromNow(7),
          {from: accounts[0], value: 5000000000000000000}
        );

        /* Approximately 5 eth should be removed from party A's balance. */
        let partyATransactionBalance = await web3.eth.getBalance(accounts[0]);
        let balanceTransactionDifference = parseInt(partyAInitialBalance.toString(), 10) - parseInt(partyATransactionBalance.toString(), 10);
        assert.isBelow(balanceTransactionDifference, 5100000000000000000, "Balance difference should be below 5.1 eth.");
        assert.isAbove(balanceTransactionDifference, 5000000000000000000, "Balance difference should be above 5.0 eth.");

        /* Get dispute ID (same as transaction ID) from ContextEvidence event. */
        let disputeID = "";
        let args = getEventFromTransaction(tx, "ContextEvidence");
        if (args) {
          disputeID = args._disputeID.toString();
        }

        /* Dispute ID should be 0 since this is the first transaction. */
        assert.equal(disputeID, "0", "Dispute ID should be 0.");

        /* Initiate dispute. */
        tx = await transactionManagerInstance.disputeTransaction(
          disputeID,
          {from: accounts[1]}
        );

        /* Both party A and party B pay arbitration fees. */
        let feesOwedObj = await arbitrationServiceInstance.getFeesOwed(transactionManagerInstance.address, disputeID);
        let partyAOwes = feesOwedObj.partyAOwes.toString();
        let partyBOwes = feesOwedObj.partyBOwes.toString();
        if (partyAOwes !== "0") {
          tx = await arbitrationServiceInstance.payFee(
            transactionManagerInstance.address, 
            disputeID,
            {from: accounts[0], value: partyAOwes}
          );
        }
        if (partyBOwes !== "0") {
          tx = await arbitrationServiceInstance.payFee(
            transactionManagerInstance.address, 
            disputeID,
            {from: accounts[1], value: partyBOwes}
          );
        }

        /* Trusted mediator rules in favor of refunding party A. */
        tx = await arbitrationServiceInstance.giveRuling(
          transactionManagerInstance.address, 
          disputeID, 
          2,
          {from: accounts[2]}
        );

        /* Party A withdraws funds. */
        tx = await transactionManagerInstance.withdraw(
          disputeID,
          {from: accounts[0]}
        );
        
        /* Party A's balance should be approximately the same as when it started. */
        let partyAFinalBalance = await web3.eth.getBalance(accounts[0]);
        let balanceFinalDifference = parseInt(partyAInitialBalance.toString(), 10) - parseInt(partyAFinalBalance.toString(), 10);
        assert.isBelow(balanceFinalDifference, 100000000000000000, "Balance difference should be below 0.1 eth.");
        assert.isAbove(balanceFinalDifference, 0, "Balance difference should be above 0 eth.");
    });    

});
