require('dotenv').config();

module.exports = async ({getNamedAccounts, deployments}) => {
    const {deploy, get} = deployments;
    const {account0, account1} = await getNamedAccounts();
    const Treasury = await get("Treasury");
    const Swaps = await get("Swaps");
    const Oracle = await get("TestOracle");
    
    await deploy('ETHHODLStrategy', {
      from: account0,
      args: [Swaps.address, Treasury.address, Oracle.address, process.env.UNISWAP_ADDRESS],
      log: true,
    });

  };
