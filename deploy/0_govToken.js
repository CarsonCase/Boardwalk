require('dotenv').config();

module.exports = async ({getNamedAccounts, deployments}) => {
    const {deploy} = deployments;
    const {account0, account1} = await getNamedAccounts();
    await deploy('GovernanceToken', {
      from: account0,
      args: [process.env.STABLECOIN_ADDRESS],
      log: true,
    });

  };
