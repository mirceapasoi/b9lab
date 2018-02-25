const Splitter = artifacts.require("./Splitter.sol");
const RockPaperScissors = artifacts.require("RockPaperScissors");

module.exports = function(deployer, network, accounts) {
  deployer.deploy(Splitter);
  deployer.deploy(RockPaperScissors);
};
