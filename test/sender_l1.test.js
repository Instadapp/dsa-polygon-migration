const hre = require("hardhat");
const { expect } = require("chai");
const { ethers, network, waffle } = hre;
const { provider, deployContract } = waffle

const Migrator = require("../artifacts/contracts/receivers/aave-v2-receiver/main.sol/AaveV2Migrator.json")
const TokenMappingContract = require("../artifacts/contracts/receivers/mapping/main.sol/InstaPolygonTokenMapping.json")
const Implementations_m2Contract = require("../artifacts/contracts/implementation/aave-v2-migrator/main.sol/InstaImplementationM1.json")

const tokenMaps = {
  // polygon address : main net address
  // '0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE': '0x7d1afa7b718fb893db30a3abc0cfc608aacfebb0', //TODO
  '0x7ceB23fD6bC0adD59E62ac25578270cFf1b9f619': '0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2', // WETH
  '0x8f3Cf7ad23Cd3CaDbD9735AFf958023239c6A063': '0x6B175474E89094C44Da98b954EedeAC495271d0F', // DAI
  '0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174': '0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48', // USDC
  '0xc2132D05D31c914a87C6611C10748AEb04B58e8F': '0xdAC17F958D2ee523a2206206994597C13D831ec7', // USDT
  '0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270': '0x7d1afa7b718fb893db30a3abc0cfc608aacfebb0',
  '0x1BFD67037B42Cf73acF2047067bd4F2C47D9BfD6': '0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599'
}

// 
describe("Migrator", function() {
  let accounts, masterAddress, master, migrator, ethereum, instapool, tokenMapping, implementations_m2Contract

  const erc20Abi = [
    "function balanceOf(address) view returns (uint)",
    "function transfer(address to, uint amount)",
    "function approve(address spender, uint amount)"
  ]

  const instaImplementationABI = [
    "function addImplementation(address _implementation, bytes4[] calldata _sigs)"
  ]

  const implementations_m2Sigs = ["0x5a19a5eb"]

  const migrateData = "0x0000000000000000000000000000000000000000000000000000000000000020000000000000000000000000150acc42e6751776c9e784eff830cb4f35ae98f300000000000000000000000000000000000000000000000000000000000000a000000000000000000000000000000000000000000000000000000000000000e00000000000000000000000000000000000000000000000000000000000000120000000000000000000000000000000000000000000000000000000000000016000000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000033f007ebdfe640000000000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000002540be4000000000000000000000000000000000000000000000000000000000000000001000000000000000000000000c02aaa39b223fe8d0a0e5c4f27ead9083c756cc20000000000000000000000000000000000000000000000000000000000000001000000000000000000000000dac17f958d2ee523a2206206994597c13d831ec7"
  // const usdc = '0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48'
  // const usdt = '0xdac17f958d2ee523a2206206994597c13d831ec7'
  // const dai = '0x8f3Cf7ad23Cd3CaDbD9735AFf958023239c6A063'
  // const wbtc = '0x2260fac5e5542a773aa44fbcfedf7c193bc2c599'
  // const aave = '0x7fc66500c84a76ad7e9c93437bfc5ac33e2ddae9'
  // const eth = '0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE'
  // const weth = '0x7ceB23fD6bC0adD59E62ac25578270cFf1b9f619'

  const instaConnectorsV2 = '0x0a0a82D2F86b9E46AE60E22FCE4e8b916F858Ddc'
  const instaImplementations = '0x39d3d5e7c11D61E072511485878dd84711c19d4A'
  

  const maxValue = '115792089237316195423570985008687907853269984665640564039457584007913129639935'

  // const supportedTokens = [usdc, usdt, dai, wbtc, aave, eth, weth]

  before(async function() {
    masterAddress = "0x31de2088f38ed7F8a4231dE03973814edA1f8773"
    await hre.network.provider.request({
      method: "hardhat_impersonateAccount",
      params: [ masterAddress ]
    })

    accounts = await ethers.getSigners();
    master = ethers.provider.getSigner(masterAddress)

    migrator = await deployContract(master, Migrator, [])
    
    // instapool = await deployContract(master, InstaPool, [])
    tokenMapping = await deployContract(master, TokenMappingContract, [Object.values(tokenMaps), Object.keys(tokenMaps)])
    console.log("Migrator deployed: ", migrator.address)
    implementations_m2Contract = await deployContract(master, Implementations_m2Contract, [instaConnectorsV2, migrator.address])
    
    console.log("Migrator deployed: ", migrator.address)
    console.log("tokenMapping deployed: ", tokenMapping.address)
    console.log("implementations_m2Contract deployed: ", implementations_m2Contract.address)
    
    await master.sendTransaction({
      to: migrator.address,
      value: ethers.utils.parseEther("9999000")
    });
    ethereum = network.provider
  })

  it("should set implementationsV2", async function() {

    const instaImplementationsContract = new ethers.Contract(instaImplementations, instaImplementationABI, master)
    await instaImplementationsContract.connect(master).addImplementation(implementations_m2Contract.address, implementations_m2Sigs)
  })

  it("should set tokens", async function() {
    const tx = await migrator.connect(master).addTokenSupport([...Object.keys(tokenMaps).slice(1, 3), "0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE"])
    const receipt = await tx.wait()

    const isMatic = await migrator.isSupportedToken("0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE")
    expect(isMatic).to.be.true;
  })

  it("should set data", async function() {
    const tx = await migrator.onStateReceive("345", migrateData)
    const receipt = await tx.wait()

    const _migrateData = await migrator.positions("345")
    console.log("_migrateData", _migrateData)
    // console.log("tokenMapping deployed: ", await tokenMapping.getMapping("0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48"))
    expect(_migrateData).to.be.eq(migrateData);

  })

    it("test settle", async function() {
    const tx = await migrator.settle()
    const receipt = await tx.wait()

    // console.log(receipt)
  })

  it("test migrate", async function() {
    // const sourceAddr = '0x42c7788dd1cef71cf04ae4d6bca37d129c27e001'

    // const rawData = {
    //   targetDsa: sourceAddr,
    //   supplyTokens: [weth],
    //   borrowTokens: [usdc],
    //   supplyAmts: [ethers.utils.parseEther('60')],
    //   variableBorrowAmts: [ethers.utils.parseUnits('10000', 6)],
    //   stableBorrowAmts: [ethers.utils.parseUnits('10000', 6)]
    // }

    // await hre.network.provider.request({
    //   method: "hardhat_impersonateAccount",
    //   params: [ sourceAddr ]
    // })
    // const signer = ethers.provider.getSigner(sourceAddr)

    // const awethContract = new ethers.Contract(aweth, erc20Abi, signer)
    // await awethContract.approve(migrator.address, maxValue)

    const tx = await migrator.migrate("345")
    const receipt = await tx.wait()

    // console.log(receipt)
  })

  // it("test settle", async function() {
  //   const tokens = [weth]
  //   const amts = [ethers.utils.parseEther('60')]

  //   const tx = await migrator.settle(tokens, amts)
  //   const receipt = await tx.wait()

  //   // console.log(receipt)
  // })

  // it("test settle 2", async function() {
  //   const tokens = [usdc]
  //   const amts = [ethers.utils.parseUnits('20000', 6)]

  //   const tx = await migrator.settle(tokens, amts)
  //   const receipt = await tx.wait()

  //   // console.log(receipt)
  // })
})