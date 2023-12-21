// Import ethers from Hardhat package
const { ethers } = require("hardhat");

async function main() {
  // This will get the contract to deploy
  const MyContract = await ethers.getContractFactory("predMarket");

  // Start deployment, returning a promise that resolves to a contract object
  const myContract = await MyContract.deploy(864000); // Instance of the contract
  console.log("Contract deployed to address:", myContract.address);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
