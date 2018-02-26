const Splitter = artifacts.require("./Splitter.sol");
const RockPaperScissors = artifacts.require("./RockPaperScissors.sol");
const Remittance = artifacts.require("./Remittance.sol");

module.exports = function(deployer, network, accounts) {
  deployer.deploy(Splitter);
  deployer.deploy(RockPaperScissors);
  deployer.deploy(Remittance);
};
