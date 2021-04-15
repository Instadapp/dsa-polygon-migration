const hre = require("hardhat");
const { expect } = require("chai");
const { ethers, network, waffle } = hre;
const { provider, deployContract } = waffle

const Migrator = require("../artifacts/contracts/senders/aave-v2-migrator/main.sol/MigrateResolver.json")

describe("Migrator", function() {
  let accounts, masterAddress, master, migrator, ethereum
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

    console.log("Migrator deployed: ", migrator.address)

    ethereum = network.provider
  })

  it("should set tokens", async function() {
    const tx = await migrator.connect(master).addTokenSupport(supportedTokens)
    const receipt = await tx.wait()

    const isUsdc = await migrator.isSupportedToken(usdc)
    expect(isUsdc).to.be.true;
  })
})