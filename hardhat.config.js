require("@nomicfoundation/hardhat-toolbox");
require("hardhat-gas-reporter");

/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
  solidity: "0.8.19",
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
