module.exports = async ({getNamedAccounts, deployments}) => {
    const {deploy} = deployments;
    const {account0, account1} = await getNamedAccounts();
    await deploy('TestOracle', {
      from: account0,
      args: [],
      log: true,
    });

  };
