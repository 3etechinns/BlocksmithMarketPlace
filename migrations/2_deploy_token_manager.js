var TokenManager = artifacts.require("./TokenManager.sol");

module.exports = function(deployer) {
  deployer.deploy(TokenManager);
};
