// Buidler
require("@nomiclabs/hardhat-ethers");
require("@nomiclabs/hardhat-waffle");
require("@nomiclabs/hardhat-web3")
require("hardhat-deploy");
require("hardhat-deploy-ethers");

require("@nomiclabs/hardhat-etherscan");

require("dotenv").config();

const { utils } = require("ethers");

const ALCHEMY_ID = process.env.ALCHEMY_ID;
const PRIVATE_KEY = process.env.PRIVATE_KEY;
// ================================= CONFIG =========================================
module.exports = {
  defaultNetwork: "hardhat",
  tenderly: {
    project: "team-development",
    username: "InstaDApp",
    forkNetwork: "1"
  },
  networks: {
    hardhat: {
      forking: {
        url: `https://eth-mainnet.alchemyapi.io/v2/${ALCHEMY_ID}`,
        blockNumber: 12240294,
      },
      blockGasLimit: 12000000,
    },
    kovan: {
      url: `https://eth-kovan.alchemyapi.io/v2/${ALCHEMY_ID}`,
      accounts: [`0x${PRIVATE_KEY}`]
    },
    mainnet: {
      url: `https://eth.alchemyapi.io/v2/${ALCHEMY_ID}`,
      accounts: [`0x${PRIVATE_KEY}`],
      timeout: 150000,
      gasPrice: parseInt(utils.parseUnits("93", "gwei"))
    },
    matic: {
      url: "https://rpc-mainnet.maticvigil.com/",
      accounts: [`0x${PRIVATE_KEY}`],
      timeout: 150000,
      gasPrice: parseInt(utils.parseUnits("1", "gwei"))
    }
  },
  solidity: {
    compilers: [
      {
        version: "0.7.6"
      },
      {
        version: "0.7.3",
      },
      {
        version: "0.7.0",
      },
      {
        version: "0.6.10",
      },
      {
        version: "0.6.8",
      }
    ]
  },
  etherscan: {
    apiKey: process.env.ETHERSCAN
  }

};