const hre = require("hardhat");
const { expect } = require("chai");
const { ethers, network, waffle } = hre;
const { provider, deployContract } = waffle

const Migrator = require("../artifacts/contracts/senders/aave-v2-migrator/main.sol/MigrateResolver.json")
const InstaPool = require("../artifacts/contracts/liquidity.sol/InstaPool.json")

describe("Migrator", function() {
  let accounts, masterAddress, master, migrator, ethereum, instapool

  const erc20Abi = [
    "function balanceOf(address) view returns (uint)",
    "function transfer(address to, uint amount)",
    "function approve(address spender, uint amount)"
  ]

  const syncStateAbi = [
    "function register(address sender, address receiver)"
  ]

  const usdc = '0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48'
  const usdt = '0xdac17f958d2ee523a2206206994597c13d831ec7'
  const dai = '0x6b175474e89094c44da98b954eedeac495271d0f'
  const wbtc = '0x2260fac5e5542a773aa44fbcfedf7c193bc2c599'
  const aave = '0x7fc66500c84a76ad7e9c93437bfc5ac33e2ddae9'
  const eth = '0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE'
  const weth = '0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2'

  const aweth = '0x030ba81f1c18d280636f32af80b9aad02cf0854e'

  const maxValue = '115792089237316195423570985008687907853269984665640564039457584007913129639935'

  const supportedTokens = [usdc, usdt, dai, wbtc, aave, eth, weth]

  before(async function() {
    masterAddress = "0xb1DC62EC38E6E3857a887210C38418E4A17Da5B2"
    await hre.network.provider.request({
      method: "hardhat_impersonateAccount",
      params: [ masterAddress ]
    })

    accounts = await ethers.getSigners();
    master = ethers.provider.getSigner(masterAddress)

    migrator = await deployContract(master, Migrator, [])
    instapool = await deployContract(master, InstaPool, [])

    console.log("Migrator deployed: ", migrator.address)
    console.log("Instapool deployed: ", instapool.address)

    const syncStateOwnerAddr = '0xFa7D2a996aC6350f4b56C043112Da0366a59b74c'
    await hre.network.provider.request({
      method: "hardhat_impersonateAccount",
      params: [ syncStateOwnerAddr ]
    })
    const syncStateOwner = ethers.provider.getSigner(syncStateOwnerAddr)
    const syncStateContract = new ethers.Contract('0x28e4F3a7f651294B9564800b2D01f35189A5bFbE', syncStateAbi, syncStateOwner)
    await accounts[0].sendTransaction({ to: syncStateOwnerAddr, value: ethers.utils.parseEther('1') })
    await syncStateContract.register(migrator.address, '0xA35f3FEFEcb5160327d1B6A210b60D1e1d7968e3')
    // await syncStateContract.register(instapool.address, '0xA35f3FEFEcb5160327d1B6A210b60D1e1d7968e3')

    const usdcHolderAddr = '0x47ac0fb4f2d84898e4d9e7b4dab3c24507a6d503' // 1,000,000
    await accounts[0].sendTransaction({ to: usdcHolderAddr, value: ethers.utils.parseEther('1') })
    await hre.network.provider.request({
      method: "hardhat_impersonateAccount",
      params: [ usdcHolderAddr ]
    })
    const usdcHolder = ethers.provider.getSigner(usdcHolderAddr)
    const usdcContract = new ethers.Contract(usdc, erc20Abi, usdcHolder)
    await usdcContract.transfer(migrator.address, ethers.utils.parseUnits('1000000', 6))

    const usdtHolderAddr = '0x47ac0fb4f2d84898e4d9e7b4dab3c24507a6d503' // 1,000,000
    await accounts[0].sendTransaction({ to: usdtHolderAddr, value: ethers.utils.parseEther('1') })
    await hre.network.provider.request({
      method: "hardhat_impersonateAccount",
      params: [ usdtHolderAddr ]
    })
    const usdtHolder = ethers.provider.getSigner(usdtHolderAddr)
    const usdtContract = new ethers.Contract(usdt, erc20Abi, usdtHolder)
    await usdtContract.transfer(migrator.address, ethers.utils.parseUnits('1000000', 6))

    const daiHolderAddr = '0x47ac0fb4f2d84898e4d9e7b4dab3c24507a6d503' // 1,000,000
    await accounts[0].sendTransaction({ to: daiHolderAddr, value: ethers.utils.parseEther('1') })
    await hre.network.provider.request({
      method: "hardhat_impersonateAccount",
      params: [ daiHolderAddr ]
    })
    const daiHolder = ethers.provider.getSigner(daiHolderAddr)
    const daiContract = new ethers.Contract(dai, erc20Abi, daiHolder)
    await daiContract.transfer(migrator.address, ethers.utils.parseUnits('1000000', 18))

    const wbtcHolderAddr = '0xf977814e90da44bfa03b6295a0616a897441acec' // 16
    await hre.network.provider.request({
      method: "hardhat_impersonateAccount",
      params: [ wbtcHolderAddr ]
    })
    const wbtcHolder = ethers.provider.getSigner(wbtcHolderAddr)
    const wbtcContract = new ethers.Contract(wbtc, erc20Abi, wbtcHolder)
    await wbtcContract.transfer(migrator.address, ethers.utils.parseUnits('16', 8))

    const wethHolderAddr = '0x0f4ee9631f4be0a63756515141281a3e2b293bbe' // 500
    await hre.network.provider.request({
      method: "hardhat_impersonateAccount",
      params: [ wethHolderAddr ]
    })
    const wethHolder = ethers.provider.getSigner(wethHolderAddr)
    const wethContract = new ethers.Contract(weth, erc20Abi, wethHolder)
    await wethContract.transfer(migrator.address, ethers.utils.parseUnits('500', 18))
    await wethContract.transfer(instapool.address, ethers.utils.parseUnits('10', 18))

    ethereum = network.provider
  })

  it("should set tokens", async function() {
    const tx = await migrator.connect(master).addTokenSupport(supportedTokens)
    const receipt = await tx.wait()

    const isUsdc = await migrator.isSupportedToken(usdc)
    expect(isUsdc).to.be.true;
  })

  it("test migrate", async function() {

    const sourceAddr = '0x05A14F14E7a435542468D6F4d408D6F67303D769'
    await master.sendTransaction({
      to: sourceAddr,
      value: ethers.utils.parseEther("1")
    });
    const rawData = {
      targetDsa: "0x150Acc42e6751776c9E784EfF830cB4f35aE98f3",
      supplyTokens: [weth],
      borrowTokens: [usdt],
      supplyAmts: [ethers.utils.parseEther('60')],
      variableBorrowAmts: [ethers.utils.parseUnits('10000', 6)],
      stableBorrowAmts: [0]
    }

    await hre.network.provider.request({
      method: "hardhat_impersonateAccount",
      params: [ sourceAddr ]
    })
    const signer = ethers.provider.getSigner(sourceAddr)

    const awethContract = new ethers.Contract(aweth, erc20Abi, signer)
    await awethContract.approve(migrator.address, maxValue)

    const tx = await migrator.connect(signer).migrateWithFlash(rawData, ethers.utils.parseEther('80'))
    const receipt = await tx.wait()

    // console.log(receipt)
  })

  it("test settle", async function() {
    const tokens = [weth]
    const amts = [ethers.utils.parseEther('60')]

    const tx = await migrator.settle(tokens, amts)
    const receipt = await tx.wait()

    // console.log(receipt)
  })

  it("test settle 2", async function() {
    const tokens = [usdc]
    const amts = [ethers.utils.parseUnits('20000', 6)]

    const tx = await migrator.settle(tokens, amts)
    const receipt = await tx.wait()

    // console.log(receipt)
  })
})