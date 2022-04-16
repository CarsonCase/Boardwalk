const hre = require("hardhat");

// variables for rinkeby
const stable = "";
const uni = "";

async function main() {
  // const GovToken = await ethers.getContractFactory("GovernanceToken");
  // govToken = await GovToken.deploy(stable);
  // await govToken.deployed();

  // const Swaps = await ethers.getContractFactory("TestSwapsNoSuperfluid");
  // swaps = await Swaps.deploy(stable);
  // await swaps.deployed();

  // const Treasury = await ethers.getContractFactory("Treasury");
  // treasury = await Treasury.deploy(stable, govToken.address, swaps.address);
  // await treasury.deployed();

  // const Oracle = await ethers.getContractFactory("TestOracle");
  // oracle = await Oracle.deploy();
  // await oracle.deployed();

  // const Strategy = await hre.ethers.getContractFactory("ETHHODLStrategy");
  // strategy = await Strategy.deploy(swaps.address, treasury.address, oracle.address, uni);
  // await strategy.deployed();

}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
