require('dotenv').config();

module.exports = async ({getNamedAccounts, deployments}) => {
    const {deploy, get} = deployments;
    const {account0, account1} = await getNamedAccounts();
    const Treasury = '0x6D992c2a6B112F856d2D7da364b5453c6c94f60e'
    const Swaps = "0xa3b171dE7DD7D732140c3628AcF2760Ee196C4c6"
    const Oracle = "0x80cf0e0d515f78cD6EDE4D0F07F0C574BeC09664"
    
    await deploy('ETHHODLStrategy', {
      from: account0,
      args: [Swaps, Treasury, Oracle, process.env.UNISWAP_ADDRESS],
      log: true,
    });

};
module.exports.tags = ['ManualStrategy'];
