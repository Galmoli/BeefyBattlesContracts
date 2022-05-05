const hre = require("hardhat");
const { expect } = require("chai");
const { airdropWant } = require("../scripts/utils");

const wantAddress = "0x74b23882a30290451A17c44f4F05243b6b58C76d"; // WETH on Fantom
const amount = hre.ethers.utils.parseEther("1");
const impersonateAddress = "0xcA436e14855323927d6e6264470DeD36455fC8bD";

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
            await airdropWant(wantAddress, account.getAddress(), amount, impersonateAddress);

            wantAmount = hre.ethers.utils.formatEther(await WANT.balanceOf(await account.getAddress()));
            expectedAmount = hre.ethers.utils.formatEther(amount);
    
            expect(wantAmount).to.eq(expectedAmount);
        });
        after(async() =>{
            balanceOfWant = await WANT.balanceOf(await account.getAddress());
            tx = await WANT.transfer(impersonateAddress, balanceOfWant);
        });
    });
})