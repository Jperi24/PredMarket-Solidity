require("@nomicfoundation/hardhat-toolbox");
require("hardhat-gas-reporter");

/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
  solidity: {
    version: "0.8.20",
    settings: {
      optimizer: {
        enabled: true, // Enable optimization
        runs: 200, // Default value for optimization
      },
    },
  },
  gasReporter: {
    enabled: true, // Enable the gas reporter
    currency: "USD", // Preferred currency
    gasPrice: 33, // Gas price to calculate costs
  },
  networks: {
    hardhat: {
      blockGasLimit: 100000000000, // Set a higher block gas limit
    },
  },
};
