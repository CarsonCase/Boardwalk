require('dotenv').config();

module.exports = async ({getNamedAccounts, deployments}) => {
    const {deploy, get} = deployments;
    const {account0, account1} = await getNamedAccounts();
    const GovToken = await get("GovernanceToken");
    const Swaps = await get("Swaps");
    await deploy('Treasury', {
      from: account0,
      args: [process.env.STABLECOIN_ADDRESS,GovToken.address,Swaps.address],
      log: true,
    });

  };
