module.exports = {
  // See <http://truffleframework.com/docs/advanced/configuration>
  // to customize your Truffle configuration!
  networks: {
    development: {
      host: "localhost",
      port: 7545,
      network_id: "*" // Match any network id
    },
    "net42": {
      host: "localhost",
      port: 8545,
      gas: 3000000,
      network_id: 42
    },
    "ropsten": {
      host: "localhost",
      port: 8545,
      gas: 3000000,
      network_id: 3
    }
  }
};
