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
    "function transfer(address to, uint amount)"
  ]

  const usdc = '0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48'
  const usdt = '0xdac17f958d2ee523a2206206994597c13d831ec7'
  const dai = '0x6b175474e89094c44da98b954eedeac495271d0f'
  const wbtc = '0x2260fac5e5542a773aa44fbcfedf7c193bc2c599'
  const aave = '0x7fc66500c84a76ad7e9c93437bfc5ac33e2ddae9'
  const eth = '0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE'
  const weth = '0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2'
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
    const sourceAddr = '0x42c7788dd1cef71cf04ae4d6bca37d129c27e001'
    const rawData = {
      targetDsa: sourceAddr,
      supplyTokens: [weth],
      borrowTokens: [usdc],
      supplyAmts: [ethers.utils.parseEther('20')],
      variableBorrowAmts: [ethers.utils.parseUnits('10000', 6)],
      stableBorrowAmts: [ethers.utils.parseUnits('10000', 6)]
    }

    await hre.network.provider.request({
      method: "hardhat_impersonateAccount",
      params: [ sourceAddr ]
    })
    const signer = ethers.provider.getSigner(sourceAddr)

    const tx = await migrator.connect(signer).migrateWithFlash(rawData, ethers.utils.parseEther('20'))
    const receipt = await tx.wait()

    console.log(receipt)
  })
})