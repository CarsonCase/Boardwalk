const { hexStripZeros } = require("@ethersproject/bytes");
const { expect, assert } = require("chai");
const { ethers } = require("hardhat");

const liquidityAmount = ethers.utils.parseEther('6',18);

describe("Dream Tests", ()=>{
  let uni, stable, govToken, treasury, swaps, oracle;
  let owner, user1, user2;

  before(async()=>{
    [owner, user1, user2] = await ethers.getSigners();
    const Stable = await ethers.getContractFactory("TestToken");
    stable = await Stable.deploy("US Dollar", "USDC");
    await stable.deployed();

    const GovToken = await ethers.getContractFactory("GovernanceToken");
    govToken = await GovToken.deploy(stable.address);
    await govToken.deployed();

    const Treasury = await ethers.getContractFactory("Treasury");
    treasury = await Treasury.deploy(stable.address, govToken.address);
    await treasury.deployed();

    const Swaps = await ethers.getContractFactory("TestSwapsNoSuperfluid");
    swaps = await Swaps.deploy(stable.address);
    await swaps.deployed();

    const Oracle = await ethers.getContractFactory("TestOracle");
    oracle = await Oracle.deploy();
    await oracle.deployed();

    uni = await ethers.getContractAt("IUniswapV2Router02","0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D");

  });

  it("Uniswap exists", async()=>{
    const weth = await uni.WETH();
    expect(weth.toString()).to.equal("0xd0A1E359811322d97991E03f863a0C30C2cF029C");
  });

  it("owner transfers ownership of govToken to treasury", async() => {
    await govToken.transferOwnership(treasury.address);
    const govOwner = await govToken.owner();
    assert.equal(govOwner, treasury.address);
  });

  it("owners adds liquidity for tokens", async()=>{
    await stable.connect(owner).approve(uni.address, liquidityAmount);
    await govToken.connect(owner).approve(uni.address, liquidityAmount);
    const balStable = await stable.balanceOf(owner.address);
    const balGov = await govToken.balanceOf(owner.address);

    assert(balGov.gt(liquidityAmount) && balStable.gt(liquidityAmount));

    await stable.connect(owner).approve(uni.address, liquidityAmount);
    await govToken.connect(owner).approve(uni.address, liquidityAmount);
    const approved = await govToken.allowance(owner.address, uni.address);

    await uni.connect(owner).addLiquidity(
      stable.address,
      govToken.address,
      liquidityAmount,
      liquidityAmount,
      0,
      0,
      owner.address,
      (await getLastBlockTimestamp()) + 30
    );

    await stable.connect(owner).approve(uni.address, liquidityAmount);
    await uni.connect(owner).addLiquidityETH(
      stable.address,
      liquidityAmount,
      0,
      0,
      owner.address,
      (await getLastBlockTimestamp()) + 30,
      {value: liquidityAmount}
    );

  })

  it("treasury sells new tokens on market", async() =>{
    await treasury.issueShares(ethers.utils.parseEther("0.2"));
    const newBal = await stable.balanceOf(treasury.address);
    const expected = await uni.getAmountOut(ethers.utils.parseEther("0.2"), liquidityAmount, liquidityAmount);
    assert.equal(newBal.toString(), expected.toString());
  });

  describe("strategies", async()=>{
    let strategy;

    it("owner deploys a new strategy", async()=>{
      const Strategy = await hre.ethers.getContractFactory("ETHHODLStrategy");
      strategy = await Strategy.deploy(swaps.address, treasury.address, oracle.address, uni.address);
      await strategy.deployed();
      assert(strategy);
    });

    it("treasury funds a strategy", async() =>{
      await treasury.transferFundsToStrategy(strategy.address, ethers.utils.parseEther("0.1"));
      const stratBal = await ethers.provider.getBalance(strategy.address);
      assert(stratBal.gt(0));
    });

    describe("swaps", async()=>{
      it("fails to issue a swap with no collateral", async()=>{
        try{
          await strategy.connect(user1).buySwap(ethers.utils.parseEther("0.1"));
        }catch(e){
          assert(e)
        }
      });

      it("owner transfers user1 some tokens", async()=>{
        await stable.transfer(user1.address, ethers.utils.parseEther("1"));
        const newBal = await stable.balanceOf(user1.address);
        assert.equal(ethers.utils.parseEther("1").toString(), newBal.toString());
      });

      it("user1 submits collateral", async()=>{
        await stable.connect(user1).approve(treasury.address, ethers.utils.parseEther("0.005"));
        await treasury.connect(user1).addCollateral(ethers.utils.parseEther("0.005"));
        const availableCollateral = await treasury.availableCollateral(user1.address);
        assert.equal(availableCollateral.toString(), ethers.utils.parseEther("0.005").toString());
      });

      it("user1 buysSwap successfuly", async()=>{
        await strategy.connect(user1).buySwap(ethers.utils.parseEther("0.05"));
        const NFTOwner = await swaps.ownerOf(1);
        assert.equal(NFTOwner, user1.address);
      });

    });
  
  
  });


});

async function getLastBlockTimestamp() {
  const blockNumber = await ethers.provider.getBlockNumber();
  const block = await ethers.provider.getBlock(blockNumber);
  return block.timestamp;
}
