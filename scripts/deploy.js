const hre = require("hardhat");
const { ethers } = hre;

async function main() {
  let instaIndex
    if (hre.network.name === "mainnet") {
      console.log(
        "\n\n Deploying Contracts to mainnet. Hit ctrl + c to abort"
      );
      instaIndex = "0x2971AdFa57b20E5a416aE5a708A8655A9c74f723"

      const InstaEmptyImpl = await ethers.getContractFactory("InstaEmptyImpl");
      const instaEmptyImpl = await InstaEmptyImpl.deploy();
      await instaEmptyImpl.deployed();

      console.log("InstaEmptyImpl deployed: ", instaEmptyImpl.address);


      const InstaMasterProxy = await ethers.getContractFactory("InstaMasterProxy");
      const instaMasterProxy = await InstaMasterProxy.deploy(instaIndex);
      await instaMasterProxy.deployed();

      console.log("InstaMasterProxy deployed: ", instaMasterProxy.address);

      const InstaAaveV2MigratorSender = await ethers.getContractFactory("InstaAaveV2MigratorSender");
      const instaAaveV2MigratorSender = await InstaAaveV2MigratorSender.deploy(instaEmptyImpl.address, instaMasterProxy.address, "0x");
      await instaAaveV2MigratorSender.deployed();

      console.log("InstaAaveV2MigratorSender deployed: ", instaAaveV2MigratorSender.address);
      
      const InstaPool = await ethers.getContractFactory("InstaPool");
      const instaPool = await InstaPool.deploy();
      await instaPool.deployed();

      console.log("InstaPool deployed: ", instaPool.address);


      const InstaAaveV2MigratorSenderImplementation = await ethers.getContractFactory("InstaAaveV2MigratorSenderImplementation");
      const instaAaveV2MigratorSenderImplementation = await InstaAaveV2MigratorSenderImplementation.deploy();
      await instaAaveV2MigratorSenderImplementation.deployed();

      console.log("InstaAaveV2MigratorSenderImplementation deployed: ", instaAaveV2MigratorSenderImplementation.address);

      const InstaAaveV2MigratorSender = await ethers.getContractFactory("InstaAaveV2MigratorSender");
      const instaAaveV2MigratorSender = await InstaAaveV2MigratorSender.deploy(instaEmptyImpl.address, instaMasterProxy.address, "0x");
      await instaAaveV2MigratorSender.deployed();

      console.log("InstaAaveV2MigratorSender deployed: ", instaAaveV2MigratorSender.address);
        
      await hre.run("verify:verify", {
            address: instaEmptyImpl.address,
            constructorArguments: [],
            contract: "contracts/proxy/dummyImpl.sol:InstaEmptyImpl"
          }
      )

      await hre.run("verify:verify", {
            address: instaMasterProxy.address,
            constructorArguments: [instaIndex],
          }
      )

      await hre.run("verify:verify", {
          address: instaAaveV2MigratorSender.address,
          constructorArguments: [instaEmptyImpl.address, instaMasterProxy.address, "0x"],
          contract: "contracts/proxy/senders.sol:InstaAaveV2MigratorSender"
        }
      )

      await hre.run("verify:verify", {
          address: instaPool.address,
          constructorArguments: []
        }
      )

      await hre.run("verify:verify", {
        address: instaAaveV2MigratorSenderImplementation.address,
        constructorArguments: []
        }
      )

    } else if (hre.network.name === "matic") {
      console.log(
        "\n\n Deploying Contracts to matic..."
      );
      instaIndex = "0xA9B99766E6C676Cf1975c0D3166F96C0848fF5ad"

      const InstaEmptyImpl = await ethers.getContractFactory("InstaEmptyImpl");
      const instaEmptyImpl = await InstaEmptyImpl.deploy();
      await instaEmptyImpl.deployed();

      console.log("InstaEmptyImpl deployed: ", instaEmptyImpl.address);


      const InstaMasterProxy = await ethers.getContractFactory("InstaMasterProxy");
      const instaMasterProxy = await InstaMasterProxy.deploy(instaIndex);
      await instaMasterProxy.deployed();

      console.log("InstaMasterProxy deployed: ", instaMasterProxy.address);

      const InstaAaveV2MigratorReceiver = await ethers.getContractFactory("InstaAaveV2MigratorReceiver");
      const instaAaveV2MigratorReceiver = await InstaAaveV2MigratorReceiver.deploy(instaEmptyImpl.address, instaMasterProxy.address, "0x");
      await instaAaveV2MigratorReceiver.deployed();

      console.log("InstaAaveV2MigratorReceiver deployed: ", instaAaveV2MigratorReceiver.address);
      
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

      const InstaPolygonTokenMapping = await ethers.getContractFactory("InstaPolygonTokenMapping");
      const instaPolygonTokenMapping = await InstaPolygonTokenMapping.deploy(Object.values(tokenMaps), Object.keys(tokenMaps));
      await instaPolygonTokenMapping.deployed();

      console.log("InstaPolygonTokenMapping deployed: ", instaPolygonTokenMappings.address);
      
      const InstaAaveV2MigratorReceiverImplementation = await ethers.getContractFactory("InstaAaveV2MigratorReceiverImplementation");
      const instaAaveV2MigratorReceiverImplementation = await InstaAaveV2MigratorReceiverImplementation.deploy();
      await instaAaveV2MigratorReceiverImplementation.deployed();

      console.log("InstaAaveV2MigratorReceiverImplementation deployed: ", instaAaveV2MigratorReceiverImplementation.address);
      
      console.log("Contracts deployed")
    }
}

main()
  .then(() => process.exit(0))
  .catch(error => {
    console.error(error);
    process.exit(1);
  });