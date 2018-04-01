const Identity = artifacts.require("./Identity.sol");
const IdentityTest = artifacts.require("./IdentityTest.sol");

module.exports = function(deployer, network, accounts) {
  deployer.deploy(Identity);
  deployer.deploy(IdentityTest);
};