const hre = require("hardhat");
const { expect } = require("chai");
const { ethers, network, waffle } = hre;
const { provider, deployContract } = waffle

const Receiver = require("../artifacts/contracts/receivers/aave-v2-receiver/main.sol/InstaAaveV2MigratorReceiverImplementation.json")
const Implementation = require("../artifacts/contracts/mock/aave-v2-migrator/main.sol/InstaImplementationM2.json")

describe("Receiver", function() {
  let accounts, account, receiver, master, implementation

  const usdc = '0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174'
  const usdt = '0xc2132D05D31c914a87C6611C10748AEb04B58e8F'
  const dai = '0x8f3Cf7ad23Cd3CaDbD9735AFf958023239c6A063'
  const wbtc = '0x1BFD67037B42Cf73acF2047067bd4F2C47D9BfD6'
  const weth = '0x7ceB23fD6bC0adD59E62ac25578270cFf1b9f619'
  const wmatic = '0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270'

  const instaImplementations = '0x39d3d5e7c11D61E072511485878dd84711c19d4A'

  const maxValue = '115792089237316195423570985008687907853269984665640564039457584007913129639935'

  const erc20Abi = [
    "function balanceOf(address) view returns (uint)",
    "function transfer(address to, uint amount)",
    "function approve(address spender, uint amount)"
  ]

  const instaImplementationABI = [
    "function addImplementation(address _implementation, bytes4[] calldata _sigs)",
    "function getImplementation(bytes4 _sig) view returns (address)",
    "function removeImplementation(address _implementation)"
  ]

  const implementations_m2Sigs = ["0x5a19a5eb"]

  before(async function() {
    accounts = await ethers.getSigners()
    account = accounts[0]

    masterAddress = "0x31de2088f38ed7F8a4231dE03973814edA1f8773"
    await hre.network.provider.request({
      method: "hardhat_impersonateAccount",
      params: [ masterAddress ]
    })

    master = ethers.provider.getSigner(masterAddress)

    receiver = await deployContract(account, Receiver, [])
    implementation = await deployContract(account, Implementation, [])

    console.log("Receiver deployed: ", receiver.address)
    console.log("ImplementationM2 deployed: ", implementation.address)

    await master.sendTransaction({
      to: receiver.address,
      value: ethers.utils.parseEther("45400000")
    })

    const usdcHolderAddr = '0x986a2fCa9eDa0e06fBf7839B89BfC006eE2a23Dd' // 1,000,000
    await account.sendTransaction({ to: usdcHolderAddr, value: ethers.utils.parseEther('1') })
    await hre.network.provider.request({
      method: "hardhat_impersonateAccount",
      params: [ usdcHolderAddr ]
    })
    const usdcHolder = ethers.provider.getSigner(usdcHolderAddr)
    const usdcContract = new ethers.Contract(usdc, erc20Abi, usdcHolder)
    await usdcContract.transfer(receiver.address, ethers.utils.parseUnits('1000000', 6))

    const daiHolderAddr = '0x7A61A0Ed364E599Ae4748D1EbE74bf236Dd27B09' // 300,000
    await accounts[0].sendTransaction({ to: daiHolderAddr, value: ethers.utils.parseEther('1') })
    await hre.network.provider.request({
      method: "hardhat_impersonateAccount",
      params: [ daiHolderAddr ]
    })
    const daiHolder = ethers.provider.getSigner(daiHolderAddr)
    const daiContract = new ethers.Contract(dai, erc20Abi, daiHolder)
    await daiContract.transfer(receiver.address, ethers.utils.parseUnits('10000', 18))
  })

  // it("should change the implementation", async function() {
  //   const funder = await deployContract(master, Funder, [])
  //   await master.sendTransaction({
  //     to: funder.address,
  //     value: ethers.utils.parseEther("10")
  //   })

  //   await funder.kill()

  //   const proxyAbi = [
  //     "function upgradeTo(address newImplementation)"
  //   ]

  //   const masterProxyAddr = '0x697860CeE594c577F18f71cAf3d8B68D913c7366'
  //   const masterProxySigner = ethers.provider.getSigner(masterProxyAddr)

  //   const receiverProxy = '0x4A090897f47993C2504144419751D6A91D79AbF4'
  //   const receiverProxyContract = new ethers.Contract(receiverProxy, proxyAbi, masterProxySigner)

  //   await receiverProxyContract.upgradeTo(receiver.address)
  // })

  it("should match matic receiver", async function() {
    const maticReceiver = await receiver.maticReceiver()

    expect(maticReceiver).to.be.equal('0x0000000000000000000000000000000000001001')
  })

  it("should set implementationsM2", async function() {

    const instaImplementationsContract = new ethers.Contract(instaImplementations, instaImplementationABI, master)
    await instaImplementationsContract.connect(master).removeImplementation('0xEAac5739eB532110431b14D01017506DBA8f7b07')
    await instaImplementationsContract.connect(master).addImplementation(implementation.address, implementations_m2Sigs)
  })

  it("single token flashloan", async function() {
    const dsaAddr = '0x150Acc42e6751776c9E784EfF830cB4f35aE98f3'

    await hre.network.provider.request({
      method: "hardhat_impersonateAccount",
      params: [ dsaAddr ]
    })

    const dsaSigner = ethers.provider.getSigner(dsaAddr)

    const aave = new ethers.utils.Interface([
      'function deposit(address,uint256,uint256,uint256)',
      'function withdraw(address,uint256,uint256,uint256)'
    ])

    const basic = new ethers.utils.Interface([
      'function withdraw(address,uint256,address,uint256,uint256)'
    ])

    const abiCoder = ethers.utils.defaultAbiCoder

    const abiData = abiCoder.encode(
      ['address', 'uint256', 'address[]', 'uint256[]', 'string[]', 'bytes[]'],
      [
        dsaAddr,
        0,
        [usdc],
        [ethers.utils.parseUnits('1000', 6)],
        ['AAVE-V2-A', 'AAVE-V2-A', 'BASIC-A'],
        [
          aave.encodeFunctionData('deposit', [usdc, ethers.utils.parseUnits('1000', 6), 0, 0]),
          aave.encodeFunctionData('withdraw', [usdc, ethers.utils.parseUnits('1000', 6), 0, 0]),
          basic.encodeFunctionData('withdraw', [usdc, ethers.utils.parseUnits('1000', 6), receiver.address, 0, 0])
        ]
      ]
    )

    // console.log('abiData', abiData)

    const tx = await receiver.connect(dsaSigner).initiateFlashLoan(
      [usdc],
      [ethers.utils.parseUnits('1000', 6)],
      0,
      abiData
    )

    await tx.wait()
  })

  it("multi token flashloan", async function() {
    const dsaAddr = '0x150Acc42e6751776c9E784EfF830cB4f35aE98f3'

    await hre.network.provider.request({
      method: "hardhat_impersonateAccount",
      params: [ dsaAddr ]
    })

    const dsaSigner = ethers.provider.getSigner(dsaAddr)

    const aave = new ethers.utils.Interface([
      'function deposit(address,uint256,uint256,uint256)',
      'function withdraw(address,uint256,uint256,uint256)'
    ])

    const basic = new ethers.utils.Interface([
      'function withdraw(address,uint256,address,uint256,uint256)'
    ])

    const abiCoder = ethers.utils.defaultAbiCoder

    const abiData = abiCoder.encode(
      ['address', 'uint256', 'address[]', 'uint256[]', 'string[]', 'bytes[]'],
      [
        dsaAddr,
        0,
        [usdc, dai],
        [ethers.utils.parseUnits('1000', 6), ethers.utils.parseEther('5000')],
        ['AAVE-V2-A', 'AAVE-V2-A', 'AAVE-V2-A', 'AAVE-V2-A', 'BASIC-A', 'BASIC-A'],
        [
          aave.encodeFunctionData('deposit', [usdc, ethers.utils.parseUnits('1000', 6), 0, 0]),
          aave.encodeFunctionData('deposit', [dai, ethers.utils.parseEther('5000'), 0, 0]),
          aave.encodeFunctionData('withdraw', [usdc, ethers.utils.parseUnits('1000', 6), 0, 0]),
          aave.encodeFunctionData('withdraw', [dai, ethers.utils.parseEther('5000'), 0, 0]),
          basic.encodeFunctionData('withdraw', [usdc, ethers.utils.parseUnits('1000', 6), receiver.address, 0, 0]),
          basic.encodeFunctionData('withdraw', [dai, ethers.utils.parseEther('5000'), receiver.address, 0, 0])
        ]
      ]
    )

    // console.log('abiData', abiData)

    const tx = await receiver.connect(dsaSigner).initiateFlashLoan(
      [usdc, dai],
      [ethers.utils.parseUnits('1000', 6), ethers.utils.parseEther('5000')],
      0,
      abiData
    )

    await tx.wait()
  })
})