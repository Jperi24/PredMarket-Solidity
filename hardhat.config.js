require("@nomicfoundation/hardhat-toolbox");
require("hardhat-gas-reporter");

/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
  solidity: "0.8.20",
  settings: {
    optimizer: {
      enabled: false, // Enable optimization
      // Set high number of runs for max optimization
    },
  },
  gasReporter: {
    enabled: true, // Set to false to disable the gas reporter
    currency: "USD", // You can set this to your preferred currency
    gasPrice: 33,
  },
  networks: {
    hardhat: {
      blockGasLimit: 100000000000, // or another higher value
    },
  },
};
