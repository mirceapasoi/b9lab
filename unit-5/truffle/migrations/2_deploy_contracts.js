const Identity = artifacts.require("./Identity.sol");

module.exports = function(deployer, network, accounts) {
  deployer.deploy(Identity);
};