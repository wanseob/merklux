/*
 * NB: since truffle-hdwallet-provider 0.0.5 you must wrap HDWallet providers in a
 * function when declaring them. Failure to do so will cause commands to hang. ex:
 * ```
 * mainnet: {
 *     provider: function() {
 *       return new HDWalletProvider(mnemonic, 'https://mainnet.infura.io/<infura-key>')
 *     },
 *     network_id: '1',
 *     gas: 4500000,
 *     gasPrice: 10000000000,
 *   },
 */

module.exports = {
  migrations_directory: "./migrations",
  // See <http://truffleframework.com/docs/advanced/configuration>
  // to customize your Truffle configuration!
  networks: {
    development: {
      host: "localhost",
      port: 8545,
      network_id: "*"
    },
    devRoot: {
      host: "localhost",
      port: 8546,
      network_id: "*"
    },
    devSide: {
      host: "localhost",
      port: 8547,
      network_id: "*"
    },
    testRoot: {
      host: "localhost",
      port: 8548,
      network_id: "*"
    },
    testSide: {
      host: "localhost",
      port: 8549,
      network_id: "*"
    }
  },
  solc: {
    optimizer: {
      enabled: true,
      runs: 500
    }
  } 
};
