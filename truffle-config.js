const HDWalletProvider = require("@truffle/hdwallet-provider");
const fs = require("fs");
const mnemonic = fs.readFileSync(".secret").toString().trim();

module.exports = {
  //   Uncommenting the defaults below
  //   provides for an easier quick-start with Ganache.
  //   You can also follow this format for other networks;
  //   see <http://truffleframework.com/docs/advanced/configuration>
  //   for more details on how to specify configuration options!

  networks: {
    development: {
      host: "localhost",
      port: 8545,
      network_id: "*",
    },
    bscTestnet: {
      provider: () =>
        new HDWalletProvider(
          mnemonic,
          `https://data-seed-prebsc-1-s1.binance.org:8545`
        ),
      network_id: 97,
      confirmations: 10,
      timeoutBlocks: 200,
      skipDryRun: true,
      gasPRice: 10000000000,
    },
  },
  compilers: {
    solc: {
      version: "0.8.3",
    },
  },
  plugins: ["truffle-plugin-verify"],
  api_keys: {
    bscscan: "I2DQ3F52GX8ZU62MTRWRVWJPG2XQZSC8GT",
  },
};
