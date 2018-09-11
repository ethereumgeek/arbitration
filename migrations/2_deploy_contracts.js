var TwoPartyMediatedArbitrationService = artifacts.require("TwoPartyMediatedArbitrationService");
var TransactionManager = artifacts.require("TransactionManager");

module.exports = function(deployer) {
  deployer.deploy(TwoPartyMediatedArbitrationService).then(function() {
    return deployer.deploy(
      TransactionManager,
      TwoPartyMediatedArbitrationService.address
    );
  });
};
