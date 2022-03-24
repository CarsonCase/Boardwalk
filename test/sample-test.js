const { hexStripZeros } = require("@ethersproject/bytes");
const { expect, assert } = require("chai");
const { ethers } = require("hardhat");

const liquidityAmount = ethers.utils.parseEther('10',18);

let uni, stable, govToken, treasury, swaps, oracle;
let owner, user1, user2;

describe("Dream Tests", ()=>{
  
    testSwapWithStrategy(
      "increasing in ETH value",        //name
      ethers.utils.parseEther("1"),     //ethStartUSD
      ethers.utils.parseEther("1.2"),   //ethEndUSD
      ethers.utils.parseEther("0.1"),   //toFundStrategy
      ethers.utils.parseEther("0.005"), //CollateralDeposit
      ethers.utils.parseEther("0.05"),  //swapBuyAmount
      );

    testSwapWithStrategy(
      "increasing a lot in ETH value",        //name
      ethers.utils.parseEther("1"),     //ethStartUSD
      ethers.utils.parseEther("4.0"),   //ethEndUSD
      ethers.utils.parseEther("0.1"),   //toFundStrategy
      ethers.utils.parseEther("0.005"), //CollateralDeposit
      ethers.utils.parseEther("0.05"),  //swapBuyAmount
      );

    testSwapWithStrategy(
      "ETH value doesn't change",
      ethers.utils.parseEther("1"),
      ethers.utils.parseEther("1"),
      ethers.utils.parseEther("0.1"),
      ethers.utils.parseEther("0.005"),
      ethers.utils.parseEther("0.05"),
      );  

    testSwapWithStrategy(
      "decreasing in ETH value",
      ethers.utils.parseEther("1"),
      ethers.utils.parseEther("0.95"),
      ethers.utils.parseEther("0.1"),
      ethers.utils.parseEther("0.005"),
      ethers.utils.parseEther("0.05"),
      );

    testSwapWithStrategy(
      "decreasing in ETH value more",
      ethers.utils.parseEther("1"),
      ethers.utils.parseEther("0.90"),
      ethers.utils.parseEther("0.1"),
      ethers.utils.parseEther("0.005"),
      ethers.utils.parseEther("0.05"),
      );

    // For known issues found with the random loop bellow 
    testSwapWithStrategy(
      "Known Error",
      ethers.utils.parseEther("50"),
      ethers.utils.parseEther(46.653885447965514.toString(), 18),
      ethers.utils.parseEther("50"),
      ethers.utils.parseEther("0.05"),
      ethers.utils.parseEther("0.5"),
      );

    for(let i = 0; i < 10; i++){
      const randNum = Math.random() * 100;

      testSwapWithStrategy(
        "Random ETH movement test #" + String(i+1) + "\n50 -> " + String(randNum),
        ethers.utils.parseEther("50"),                    // starting at 50
        ethers.utils.parseUnits(randNum.toString(), 18),  // ending between 1 and 100
        ethers.utils.parseEther("10"),
        ethers.utils.parseEther("0.005"),
        ethers.utils.parseEther("0.05"),
        );  
    }
});

function testSwapWithStrategy(
  name,
  ethStartValueInUSD,
  ethEndValueInUSD,
  toFundStrategy,
  collateralDeposit,
  swapBuyAmount,
){

  describe(name,()=>{
    let strategy;
    let user;
    before(async()=>{
      [owner, user, user2] = await ethers.getSigners();
      const Stable = await ethers.getContractFactory("TestToken");
      stable = await Stable.deploy("US Dollar", "USDC");
      await stable.deployed();

      const GovToken = await ethers.getContractFactory("GovernanceToken");
      govToken = await GovToken.deploy(stable.address);
      await govToken.deployed();
    
      const Swaps = await ethers.getContractFactory("TestSwapsNoSuperfluid");
      swaps = await Swaps.deploy(stable.address);
      await swaps.deployed();
    
      const Treasury = await ethers.getContractFactory("Treasury");
      treasury = await Treasury.deploy(stable.address, govToken.address, swaps.address);
      await treasury.deployed();
    
      const Oracle = await ethers.getContractFactory("TestOracle");
      oracle = await Oracle.deploy();
      await oracle.deployed();

      FakeDex = await ethers.getContractFactory("TestDex");
      uni = await FakeDex.deploy(oracle.address,stable.address);

      const Strategy = await hre.ethers.getContractFactory("ETHHODLStrategy");
      strategy = await Strategy.deploy(swaps.address, treasury.address, oracle.address, uni.address);
      await strategy.deployed();

      const ethAddress = await strategy.eth();
      await oracle.setPriceOf(ethAddress, ethStartValueInUSD);  

    });

    describe("Setting everything up",()=>{  
  
      // it("Uniswap exists", async()=>{
      //   const weth = await uni.WETH();
      //   expect(weth.toString()).to.equal("0xd0A1E359811322d97991E03f863a0C30C2cF029C");
      // });
  
      it("owner transfers ownership of govToken to treasury", async() => {
        await govToken.transferOwnership(treasury.address);
        const govOwner = await govToken.owner();
        assert.equal(govOwner, treasury.address);
      });
  
      it("owners adds liquidity for tokens", async()=>{
        await stable.connect(owner).approve(uni.address, ethers.utils.parseEther("50"));
        await govToken.connect(owner).approve(uni.address, liquidityAmount);
        const balStable = await stable.balanceOf(owner.address);
        const balGov = await govToken.balanceOf(owner.address);
  
        assert(balGov.gte(liquidityAmount) && balStable.gte(ethers.utils.parseEther("50")), "Owner doesn't have enough tokens");
  
        const approved = await govToken.allowance(owner.address, uni.address);
        
        // commented out for fake dex
        // await uni.connect(owner).addLiquidity(
        //   stable.address,
        //   govToken.address,
        //   liquidityAmount,
        //   liquidityAmount,
        //   0,
        //   0,
        //   owner.address,
        //   (await getLastBlockTimestamp()) + 30
        // );
  
        await uni.connect(owner).addLiquidityETH(
          stable.address,
          ethers.utils.parseEther("50"),
          0,
          0,
          owner.address,
          (await getLastBlockTimestamp()) + 30,
          {value: ethers.utils.parseEther("50")}
        );
  
      });
      
      // commented out for fake dex
      // it("treasury sells new tokens on market", async() =>{
      //   await treasury.issueShares(ethers.utils.parseEther("0.2"));
      //   const newBal = await stable.balanceOf(treasury.address);
      //   const expected = await uni.getAmountOut(ethers.utils.parseEther("0.2"), liquidityAmount, liquidityAmount);
      //   assert.equal(newBal.toString(), expected.toString());
      // });
      it("treasury is given test stables", async() =>{
        await stable.mint(treasury.address, toFundStrategy);
        const treasuryBal = await stable.balanceOf(treasury.address);
        assert.equal(treasuryBal.toString(), toFundStrategy.toString());
      });
  
    });
  
    describe("strategy creation",()=>{
      it("treasury funds the strategy", async() =>{
        await treasury.transferFundsToStrategy(strategy.address, toFundStrategy);
        const stratBal = await ethers.provider.getBalance(strategy.address);
        assert.equal(stratBal.toString(), (toFundStrategy.mul(ethers.utils.parseEther("1")).div(ethStartValueInUSD)).toString());
      });
    
      it("fails to issue a swap with no collateral", async()=>{
        try{
          await strategy.connect(user).buySwap(swapBuyAmount);
        }catch(e){
          assert(e)
        }
      });
  
    });
  
    describe("collateral addition", ()=>{
      it("owner transfers user some tokens", async()=>{
        await stable.transfer(user.address, collateralDeposit);
        const newBal = await stable.balanceOf(user.address);
        assert.equal(collateralDeposit.toString(), newBal.toString());
      });
    
      it("user submits collateral", async()=>{
        await stable.connect(user).approve(treasury.address, collateralDeposit);
        await treasury.connect(user).addCollateral(collateralDeposit);
        const availableCollateral = await treasury.availableCollateral(user.address);
        assert.equal(availableCollateral.toString(), collateralDeposit.toString());
      });
    
      it("user fails to issue a swap with too little collateral", async()=>{
        try{
          await strategy.connect(user).buySwap(collateralDeposit.mul(11));
        }catch(e){
          assert(e)
        } 
      });  
    });
  
    describe("swaps",()=>{
      it("user buysSwap successfuly", async()=>{
        await strategy.connect(user).buySwap(swapBuyAmount);
        const NFTOwner = await swaps.ownerOf(1);
        assert.equal(NFTOwner, user.address);
      });
    
      it("change in price", async()=>{
        const ethAddress = await strategy.eth();
        await oracle.setPriceOf(ethAddress, ethEndValueInUSD);
        const price = await oracle.priceOf(ethAddress);
        assert.equal(price[0].toString(), ethEndValueInUSD.toString());
      });
    
      it("user ends his swap for the correct change in collateral", async()=>{
        const ethBefore = await ethers.provider.getBalance(user.address);
        const balBefore = await stable.balanceOf(user.address);
        const agreementId = await swaps._generateFlowId(user.address,swaps.address);

        await swaps.connect(user).afterAgreementTerminated(agreementId);
        const balAfter = await stable.balanceOf(user.address);
        const colAfter = await treasury.availableCollateral(user.address);
        const ethAfter = await ethers.provider.getBalance(user.address);

        if(ethEndValueInUSD.gt(ethStartValueInUSD)){
          assert.isAtMost(balAfter.sub(balBefore).sub(ethEndValueInUSD.sub(ethStartValueInUSD)).mul(swapBuyAmount).div(ethers.utils.parseEther("1")), 10);
        }else{
          const factor = (ethStartValueInUSD.sub(ethEndValueInUSD));
          
          assert.equal((balAfter.sub(balBefore).toString()), "0");
          const change = ethStartValueInUSD.sub(ethEndValueInUSD).mul(swapBuyAmount).div(ethers.utils.parseEther("1"));
          if(change.gt(collateralDeposit.sub(colAfter))){
            assert.equal(colAfter,0);
          }else{
            assert.equal(collateralDeposit.sub(colAfter).toString(), change.toString())
          }
        }
      });
    
    });
  
  })

}

async function getLastBlockTimestamp() {
  const blockNumber = await ethers.provider.getBlockNumber();
  const block = await ethers.provider.getBlock(blockNumber);
  return block.timestamp;
}
