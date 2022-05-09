const hre = require("hardhat");
const { expect } = require("chai");
const { expectRevert, time } = require("@openzeppelin/test-helpers");
const { airdropWant } = require("../scripts/utils");

const name = "BBEvent-DAI";
const symbol = "BBE-DAI";
const wantAddress = "0x8D11eC38a3EB5E956B052f67Da8Bdc9bef8Abf3E";
const beefyVaultAddress = "0x920786cff2A6f601975874Bb24C63f0115Df7dc8";
const entranceFee = hre.ethers.utils.parseEther("10");
const addressWithWant = "0xa75ede99f376dd47f3993bc77037f61b5737c6ea"; //Impersonated in airdropWant
const eventLength = 100;

describe("Beefy Battles Event", () => {
    before(async () =>{
        accounts = await hre.ethers.getSigners();
        deployer = accounts[0];
        server = accounts[1];
        user = accounts[2];
        secondaryUser = accounts[3];
        endBlock = await (await hre.ethers.provider.getBlock("latest")).number + eventLength;

        BBEvent = await hre.ethers.getContractFactory("BeefyBattlesEventV1", deployer);
        bbEvent = await BBEvent.deploy(name, symbol, wantAddress, beefyVaultAddress, server.address, entranceFee, endBlock);

        want = await hre.ethers.getContractAt("IERC20", wantAddress);
        mooToken = await hre.ethers.getContractAt("IERC20", beefyVaultAddress);

        await bbEvent.deployed();

        await airdropWant(wantAddress, user.address, hre.ethers.utils.parseEther("10"), addressWithWant);
        await airdropWant(wantAddress, secondaryUser.address, hre.ethers.utils.parseEther("10"), addressWithWant);
    });
    describe("Server Logic", async ()=> {
        it("Sets Server", async() => {
            await bbEvent.setServer(server.address);

            sAddress = await bbEvent.server();
            expect(sAddress).to.eq(server.address);
        });
        it("Only owner can setServer", async() => {
            await expectRevert(bbEvent.connect(user).setServer(user.address), "Ownable: caller is not the owner");
        })
        it("Only server can post results", async() => {
            await expectRevert(bbEvent.connect(user).postResult(user.address, deployer.address, 10, 10), "Caller is not the server");
        });
    });
    describe("Deposit Logic", async ()=> {
        it("Can't deposit if the event is CLOSED", async () => {
            await expectRevert(bbEvent.connect(user).deposit(1), "Event not open");
        });
        it("Deposit want", async () => {
            await bbEvent.connect(deployer).openEvent();
            
            await want.connect(user).approve(bbEvent.address, hre.ethers.utils.parseEther("10000"));
            await bbEvent.connect(user).deposit(1);

            mooBalance = await mooToken.balanceOf(bbEvent.address)
            mooBalance = hre.ethers.utils.formatEther(mooBalance);

            expect(parseFloat(mooBalance)).to.greaterThan(5);
        });
        it("Receives ERC721 Ticket", async () => {
            erc721Balance = await bbEvent.balanceOf(user.address)
            expect(parseFloat(erc721Balance)).to.eq(1);
        });
        it("Can't deposit twice in event", async () => {
            await expectRevert(bbEvent.connect(user).deposit(1), "User already deposited");
        });
    });
    describe("Withdraw Logic", async ()=> {
        it("Can't withdraw another user's tokenId", async () => {
            await want.connect(secondaryUser).approve(bbEvent.address, hre.ethers.utils.parseEther("10"));
            await bbEvent.connect(secondaryUser).deposit(1);

            await expectRevert(bbEvent.connect(user).withdraw(2), "Not the owner");
        });
        it("Gets the initial entry Fee", async () => {
            await bbEvent.connect(user).approve(bbEvent.address, 1);
            await bbEvent.connect(user).withdraw(1);

            balanceOfWant = await want.balanceOf(user.address);
            balanceOfWant = hre.ethers.utils.formatEther(balanceOfWant);            
            entryFeeinEther = hre.ethers.utils.formatEther(entranceFee);

            expect(balanceOfWant).to.eq(entryFeeinEther);
        });
        it("Burns the ERC721 Ticket", async () => {
            erc721Balance = await bbEvent.balanceOf(user.address)
            expect(parseFloat(erc721Balance)).to.eq(0);
        });
    });
    describe("Battle results Logic", async () =>{
        before(async () => {
            await bbEvent.connect(user).deposit(1);
        });
        it("Can't set result if token doesn't exist", async()=>{
            await expectRevert(bbEvent.connect(server).postResult(10,2,10,0), "Token doesn't exist");
        });
        it("Sets the result", async () => {
            await bbEvent.connect(server).postResult(3,2,10,0);
            userPosition = await bbEvent.calculateLeaderboardPosition(3);
            expect(userPosition.toNumber()).to.eq(0);
        });
    });
    describe("Rewards Logic", async() => {
        it("Can't harvest rewards if event hasn't ended", async () => {
            await expectRevert(bbEvent.connect(user).harvestRewards(), "Event didn't end");
        });
        it("Harvests rewards", async() =>{
            await time.advanceBlockTo(endBlock);
            await bbEvent.connect(user).harvestRewards();

            rewardPoolBalance = await want.balanceOf(await bbEvent.getRewardPool());
            rewardPoolBalance = hre.ethers.utils.formatEther(rewardPoolBalance);

            expect(parseFloat(rewardPoolBalance)).to.gt(0);
        });
    });
});