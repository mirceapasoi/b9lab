const Splitter = artifacts.require("./Splitter.sol");

module.exports = function(deployer, network, accounts) {
  // set owner, alice, bob, carol just like in the tests
  deployer.deploy(Splitter, accounts[2], accounts[3], accounts[4], {from: accounts[1]});
};
