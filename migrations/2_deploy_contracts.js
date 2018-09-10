var TransactionManager = artifacts.require("TransactionManager");

module.exports = function(deployer) {
  deployer.deploy(TransactionManager);
};
