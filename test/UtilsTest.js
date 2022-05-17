const hre = require("hardhat");
const { expect } = require("chai");
const { airdropWant } = require("../scripts/utils");

const wantAddress = "0x74b23882a30290451A17c44f4F05243b6b58C76d"; // WETH on Fantom
const amount = hre.ethers.utils.parseEther("1");
const addressWithWant = "0x04d7c2ee4cdbac9a0fc46d3e35e79aba5cca471d";

describe("Utils", () => {
    before(async()=>{
        accounts = await hre.ethers.getSigners();
        account = accounts[0];
    });
    
    describe("Airdrop ERC20 token", async() =>{
        before(async() =>{
            WANT = await hre.ethers.getContractAt("IERC20", wantAddress);
        });
        it("Airdrop WETH to address", async () => {
            await airdropWant(wantAddress, account.address, amount, addressWithWant);

            wantAmount = hre.ethers.utils.formatEther(await WANT.balanceOf(account.address));
            expectedAmount = hre.ethers.utils.formatEther(amount);
    
            expect(wantAmount).to.eq(expectedAmount);
        });
        after(async() =>{
            balanceOfWant = await WANT.balanceOf(account.address);
            tx = await WANT.transfer(addressWithWant, balanceOfWant);
        });
    });
})