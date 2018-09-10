const HDWalletProvider = require("truffle-hdwallet-provider");
const key = "";
const passphrase = "";

module.exports = {
  migrations_directory: "./migrations",
  networks: {
    development: {
      host: "localhost",
      port: 8545,
      network_id: "*" // Match any network id
    },
    "live": {
      network_id: 1,
      host: "127.0.0.1",
      port: 8546  // Different than the default below
    },
    ropsten: {
      host: "127.0.0.1",
      port: 8545,
      network_id: 3,
      gas: 4700000
    },
    rinkeby: {
      host: "127.0.0.1",
      port: 8545,
      network_id: 4,
      gas: 4700000
    },
    kovan: {
      host: "127.0.0.1",
      port: 8545,
      network_id: 42,
      gas: 4700000
    },
    "live-infura": {
        provider: () => new HDWalletProvider(passphrase, "https://mainnet.infura.io/v3/" + key),
        network_id: 1
    },
    "ropsten-infura": {
      provider: () => new HDWalletProvider(passphrase, "https://ropsten.infura.io/v3/" + key),
      network_id: 3,
      gas: 4700000
    },
    "rinkeby-infura": {
      provider: () => new HDWalletProvider(passphrase, "https://rinkeby.infura.io/v3/" + key),
      network_id: 4,
      gas: 4700000
    },
    "kovan-infura": {
      provider: () => new HDWalletProvider(passphrase, "https://kovan.infura.io/v3/" + key),
      network_id: 42,
      gas: 4700000
    }
  },
  solc: {
    optimizer: {
      enabled: true,
      runs: 500
    }
  },
  mocha: {
    enableTimeouts: false
  }
};
