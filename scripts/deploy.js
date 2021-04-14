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
      console.log("Contracts deployed")
    }
}

main()
  .then(() => process.exit(0))
  .catch(error => {
    console.error(error);
    process.exit(1);
  });