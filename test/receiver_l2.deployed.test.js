const hre = require("hardhat");
const { expect } = require("chai");
const { ethers, network, waffle } = hre;
const { provider, deployContract } = waffle

const Migrator = require("../artifacts/contracts/receivers/aave-v2-receiver/main.sol/InstaAaveV2MigratorReceiverImplementation.json")
const TokenMappingContract = require("../artifacts/contracts/receivers/mapping/main.sol/InstaPolygonTokenMapping.json")
const Implementations_m2Contract = require("../artifacts/contracts/implementation/aave-v2-migrator/main.sol/InstaImplementationM1.json")

const tokenMaps = {
  // polygon address : main net address
  // '0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE': '0x7d1afa7b718fb893db30a3abc0cfc608aacfebb0', //TODO
  '0x7ceB23fD6bC0adD59E62ac25578270cFf1b9f619': '0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2', // WETH
  '0x8f3Cf7ad23Cd3CaDbD9735AFf958023239c6A063': '0x6B175474E89094C44Da98b954EedeAC495271d0F', // DAI
  '0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174': '0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48', // USDC
  '0xc2132D05D31c914a87C6611C10748AEb04B58e8F': '0xdAC17F958D2ee523a2206206994597C13D831ec7', // USDT
  '0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270': '0x7d1afa7b718fb893db30a3abc0cfc608aacfebb0', // MATIC
  '0x1BFD67037B42Cf73acF2047067bd4F2C47D9BfD6': '0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599', // WBTC
  // '0xD6DF932A45C0f255f85145f286eA0b292B21C90B': '0x7fc66500c84a76ad7e9c93437bfc5ac33e2ddae9' // AAVE
}

// 
describe("Migrator", function() {
  let accounts, masterAddress, master, migrator, ethereum, instapool, tokenMapping, implementations_m2Contract, receiverSigner

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
  
  const usdc = '0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174'
  const usdt = '0xc2132D05D31c914a87C6611C10748AEb04B58e8F'
  const dai = '0x8f3Cf7ad23Cd3CaDbD9735AFf958023239c6A063'
  const wbtc = '0x1BFD67037B42Cf73acF2047067bd4F2C47D9BfD6'
  const aave = '0xD6DF932A45C0f255f85145f286eA0b292B21C90B'
  const weth = '0x7ceB23fD6bC0adD59E62ac25578270cFf1b9f619'
  const wmatic = '0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270'

  const receiverMsgSender = '0x0000000000000000000000000000000000001001'

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

    await hre.network.provider.request({
      method: "hardhat_impersonateAccount",
      params: [ receiverMsgSender ]
    })

    receiverSigner = ethers.provider.getSigner(receiverMsgSender)

    accounts = await ethers.getSigners();
    master = ethers.provider.getSigner(masterAddress)

    // migrator = await deployContract(master, Migrator, [])
    migrator = new ethers.Contract('0xd7e8E6f5deCc5642B77a5dD0e445965B128a585D', Migrator.abi, master)
    
    // tokenMapping = await deployContract(master, TokenMappingContract, [Object.values(tokenMaps), Object.keys(tokenMaps)])
    tokenMapping = new ethers.Contract('0xa471D83e526B6b5D6c876088D34834B44D4064ff', TokenMappingContract.abi, master)
    implementations_m2Contract = await deployContract(master, Implementations_m2Contract, [instaConnectorsV2, migrator.address])
    
    console.log("Migrator deployed: ", migrator.address)
    console.log("tokenMapping deployed: ", tokenMapping.address)
    console.log("implementations_m2Contract deployed: ", implementations_m2Contract.address)
    
    await master.sendTransaction({
      to: migrator.address,
      value: ethers.utils.parseEther("45499999")
    });

    await master.sendTransaction({
      to: receiverMsgSender,
      value: ethers.utils.parseEther("1")
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
    const tx = await migrator.connect(receiverSigner).onStateReceive("345", migrateData)
    const receipt = await tx.wait()

    const _migrateData = await migrator.positions("345")
    // console.log("_migrateData", _migrateData)
    // console.log("tokenMapping deployed: ", await tokenMapping.getMapping("0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48"))
    expect(_migrateData).to.be.eq(migrateData);

  })

  it("test settle", async function() {
    const tx = await migrator.settle()
    const receipt = await tx.wait()

    // console.log(receipt)
  })

  it("test migrate", async function() {

    const tx = await migrator.migrate("345")
    const receipt = await tx.wait()

    // console.log(receipt)
  })

  it("fund assets", async function() {
    const usdcHolderAddr = '0x986a2fCa9eDa0e06fBf7839B89BfC006eE2a23Dd' // 1,000,000
    await accounts[0].sendTransaction({ to: usdcHolderAddr, value: ethers.utils.parseEther('1') })
    await hre.network.provider.request({
      method: "hardhat_impersonateAccount",
      params: [ usdcHolderAddr ]
    })
    const usdcHolder = ethers.provider.getSigner(usdcHolderAddr)
    const usdcContract = new ethers.Contract(usdc, erc20Abi, usdcHolder)
    await usdcContract.transfer(migrator.address, ethers.utils.parseUnits('1000000', 6))

    const usdtHolderAddr = '0xe67e43b831A541c5Fa40DE52aB0aFbE311514E64' // 500,000
    await accounts[0].sendTransaction({ to: usdtHolderAddr, value: ethers.utils.parseEther('1') })
    await hre.network.provider.request({
      method: "hardhat_impersonateAccount",
      params: [ usdtHolderAddr ]
    })
    const usdtHolder = ethers.provider.getSigner(usdtHolderAddr)
    const usdtContract = new ethers.Contract(usdt, erc20Abi, usdtHolder)
    await usdtContract.transfer(migrator.address, ethers.utils.parseUnits('500000', 6))

    const daiHolderAddr = '0x7A61A0Ed364E599Ae4748D1EbE74bf236Dd27B09' // 300,000
    await accounts[0].sendTransaction({ to: daiHolderAddr, value: ethers.utils.parseEther('1') })
    await hre.network.provider.request({
      method: "hardhat_impersonateAccount",
      params: [ daiHolderAddr ]
    })
    const daiHolder = ethers.provider.getSigner(daiHolderAddr)
    const daiContract = new ethers.Contract(dai, erc20Abi, daiHolder)
    await daiContract.transfer(migrator.address, ethers.utils.parseUnits('300000', 18))

    // const wbtcHolderAddr = '0x4572581Fc62D4477B9E11bb65eA8a1c306CbBa3D' // 1
    // await hre.network.provider.request({
    //   method: "hardhat_impersonateAccount",
    //   params: [ wbtcHolderAddr ]
    // })
    // const wbtcHolder = ethers.provider.getSigner(wbtcHolderAddr)
    // const wbtcContract = new ethers.Contract(wbtc, erc20Abi, wbtcHolder)
    // await wbtcContract.transfer(migrator.address, ethers.utils.parseUnits('0.5', 8))

    let wethHolderAddr = '0xac1513a6C4C3E74Cb0c1f77c8cBbbf22A2400e33' // 150
    await hre.network.provider.request({
      method: "hardhat_impersonateAccount",
      params: [ wethHolderAddr ]
    })
    let wethHolder = ethers.provider.getSigner(wethHolderAddr)
    let wethContract = new ethers.Contract(weth, erc20Abi, wethHolder)
    await wethContract.transfer(migrator.address, ethers.utils.parseUnits('150', 18))

    wethHolderAddr = '0xBe31a54c78f6E73819ffF78072Be1660485c8105' // 130
    await hre.network.provider.request({
      method: "hardhat_impersonateAccount",
      params: [ wethHolderAddr ]
    })
    wethHolder = ethers.provider.getSigner(wethHolderAddr)
    wethContract = new ethers.Contract(weth, erc20Abi, wethHolder)
    await wethContract.transfer(migrator.address, ethers.utils.parseUnits('130', 18))

    wethHolderAddr = '0x10752de2972390BA3D5A47A26179E526019C01c0' // 100
    await hre.network.provider.request({
      method: "hardhat_impersonateAccount",
      params: [ wethHolderAddr ]
    })
    wethHolder = ethers.provider.getSigner(wethHolderAddr)
    wethContract = new ethers.Contract(weth, erc20Abi, wethHolder)
    await wethContract.transfer(migrator.address, ethers.utils.parseUnits('100', 18))

    wethHolderAddr = '0x0ee5CDBec0665D31ee00EE35b46e85EdcB9CEb31' // 100
    await hre.network.provider.request({
      method: "hardhat_impersonateAccount",
      params: [ wethHolderAddr ]
    })
    wethHolder = ethers.provider.getSigner(wethHolderAddr)
    wethContract = new ethers.Contract(weth, erc20Abi, wethHolder)
    await wethContract.transfer(migrator.address, ethers.utils.parseUnits('100', 18))

    wethHolderAddr = '0xE3f892174190b3F0Fa502Eb84c8208c7c0998c50' // 90
    await hre.network.provider.request({
      method: "hardhat_impersonateAccount",
      params: [ wethHolderAddr ]
    })
    wethHolder = ethers.provider.getSigner(wethHolderAddr)
    wethContract = new ethers.Contract(weth, erc20Abi, wethHolder)
    await wethContract.transfer(migrator.address, ethers.utils.parseUnits('100', 18))

    await hre.network.provider.request({
      method: "hardhat_impersonateAccount",
      params: [ wmatic ]
    })
    const wmaticSigner = ethers.provider.getSigner(wmatic)
    await wmaticSigner.sendTransaction({
      to: migrator.address,
      value: ethers.utils.parseEther("50000000")
    });
  })

  it("test settle 2", async function() {
    const tx = await migrator.settle()
    const receipt = await tx.wait()

    // console.log(receipt)
  })

  it("test migrate 2", async function() {
    const positionData = '0x0000000000000000000000000000000000000000000000000000000000000020000000000000000000000000150acc42e6751776c9e784eff830cb4f35ae98f300000000000000000000000000000000000000000000000000000000000000a000000000000000000000000000000000000000000000000000000000000000e0000000000000000000000000000000000000000000000000000000000000016000000000000000000000000000000000000000000000000000000000000001a000000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000056900d33ca7fc0000000000000000000000000000000000000000000000000000000000000000000300000000000000000000000000000000000000000000000000000004a817c80000000000000000000000000000000000000000000000000000000004a817c800000000000000000000000000000000000000000000000878678326eac90000000000000000000000000000000000000000000000000000000000000000000001000000000000000000000000c02aaa39b223fe8d0a0e5c4f27ead9083c756cc20000000000000000000000000000000000000000000000000000000000000003000000000000000000000000a0b86991c6218b36c1d19d4a2e9eb0ce3606eb48000000000000000000000000dac17f958d2ee523a2206206994597c13d831ec70000000000000000000000006b175474e89094c44da98b954eedeac495271d0f'
    let tx = await migrator.connect(receiverSigner).onStateReceive("346", positionData)
    await tx.wait()

    tx = await migrator.migrate("346")
    await tx.wait()
  })

  it("test settle 3", async function() {
    const tx = await migrator.settle()
    const receipt = await tx.wait()

    // console.log(receipt)
  })

  it("test migrate 3", async function() {
    const positionData = '0x000000000000000000000000000000000000000000000000000000000000002000000000000000000000000032d99500f7621c6dc5391395d419236383dbff9700000000000000000000000000000000000000000000000000000000000000a000000000000000000000000000000000000000000000000000000000000000e00000000000000000000000000000000000000000000000000000000000000140000000000000000000000000000000000000000000000000000000000000018000000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000361a08405e8fd8000000000000000000000000000000000000000000000000000000000000000000020000000000000000000000000000000000000000000000000000000df847580000000000000000000000000000000000000000000000000000000009502f90000000000000000000000000000000000000000000000000000000000000000001000000000000000000000000c02aaa39b223fe8d0a0e5c4f27ead9083c756cc20000000000000000000000000000000000000000000000000000000000000002000000000000000000000000a0b86991c6218b36c1d19d4a2e9eb0ce3606eb48000000000000000000000000dac17f958d2ee523a2206206994597c13d831ec7'
    let tx = await migrator.connect(receiverSigner).onStateReceive("347", positionData)
    await tx.wait()

    tx = await migrator.migrate("347")
    await tx.wait()
  })

  it("test settle 4", async function() {
    const tx = await migrator.settle()
    const receipt = await tx.wait()

    // console.log(receipt)
  })

  it("test migrate 4", async function() {
    const positionData = '0x000000000000000000000000000000000000000000000000000000000000002000000000000000000000000029601161ad5da8c54435f4065af3a0ee30cb24dd00000000000000000000000000000000000000000000000000000000000000a00000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000000014000000000000000000000000000000000000000000000000000000000000001a000000000000000000000000000000000000000000000000000000000000000020000000000000000000000000000000000000000000000d86821017a3f60000000000000000000000000000000000000000000000000000000000000b274d080000000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000574fbde60000000000000000000000000000000000000000000000000000000000000000002000000000000000000000000c02aaa39b223fe8d0a0e5c4f27ead9083c756cc20000000000000000000000002260fac5e5542a773aa44fbcfedf7c193bc2c5990000000000000000000000000000000000000000000000000000000000000001000000000000000000000000a0b86991c6218b36c1d19d4a2e9eb0ce3606eb48'
    let tx = await migrator.connect(receiverSigner).onStateReceive("348", positionData)
    await tx.wait()

    tx = await migrator.migrate("348")
    await tx.wait()
  })
})