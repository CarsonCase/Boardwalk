require("@nomiclabs/hardhat-waffle");
require('hardhat-deploy')
require('dotenv').config()

// This is a sample Hardhat task. To learn how to create your own go to
// https://hardhat.org/guides/create-task.html
task("accounts", "Prints the list of accounts", async (taskArgs, hre) => {
  const accounts = await hre.ethers.getSigners();

  for (const account of accounts) {
    console.log(account.address);
  }
});

// You need to export an object to set up your config
// Go to https://hardhat.org/config/ to learn more

/**
 * @type import('hardhat/config').HardhatUserConfig
 */
module.exports = {
  solidity: "0.8.4",
  networks: {
    kovan: {
      url: `https://kovan.infura.io/v3/f553bd384ac24141914e8fe56a7f3dd5`,
      network_id: 42, // Kovan's id
      networkCheckTimeout: 999999,
      timeoutBlocks: 200,
    },
    rinkeby: {
      url: process.env.NETWORK_ENDPOINT_RINKEBY,
      accounts: [process.env.ACCOUNT_0_PRIVATE_KEY]
    },
    hardhat: {
      forking: {
        url: process.env.NETWORK_ENDPOINT_RINKEBY,
      },
    },
  },
  etherscan: {
    apiKey: process.env.ETHERSCAN_API_KEY
  },
  namedAccounts: {
    account0: 0
  }
};
