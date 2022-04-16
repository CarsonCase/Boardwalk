require('dotenv').config();

module.exports = async ({getNamedAccounts, deployments}) => {
    const {deploy} = deployments;
    const {account0, account1} = await getNamedAccounts();
    await deploy('Swaps', {
      from: account0,
      args: [process.env.SUPERFLUID_HOST, process.env.SUPERFLUID_CFA, process.env.STABLECOIN_ADDRESS],
      log: true,
    });

  };
