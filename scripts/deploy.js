const hre = require("hardhat");
const { addressBook } = require("blockchain-addressbook");

const {
    tokens: {
      BOO: { address: BOO },
    },
  } = addressBook.fantom;

const eventParams = {
    eventName: "BeefyBattles Event BOO",
    eventSymbol: "BBE-BOO",
    wantAddress: BOO,
    beefyVaultAddress: "0x15DD4398721733D8273FD4Ed9ac5eadC6c018866",
    serverAddress: "0x70997970c51812dc3a010c7d01b50e0d17dc79c8",
    entranceFee: hre.ethers.utils.parseEther("10"),
    eventLength: 100000
}

async function main() {
    const currentBlock = await hre.ethers.provider.getBlock("latest");

    const eventArguments = [
        eventParams.eventName,
        eventParams.eventSymbol,
        eventParams.wantAddress,
        eventParams.beefyVaultAddress,
        eventParams.serverAddress,
        eventParams.entranceFee,
        currentBlock.number + eventParams.eventLength
    ]

    const BBEVENT = await hre.ethers.getContractFactory("BeefyBattlesEventV1");
    const bbEvent = await BBEVENT.deploy(...eventArguments);
  
    await bbEvent.deployed();
  
    console.log("BeefyBattlesEventV1 deloyed to to:", bbEvent.address);
  }
  
  main()
    .then(() => process.exit(0))
    .catch((error) => {
      console.error(error);
      process.exit(1);
});