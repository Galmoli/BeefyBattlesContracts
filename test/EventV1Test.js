const hre = require("hardhat");
const { expect } = require("chai");
const { expectRevert } = require("@openzeppelin/test-helpers");
const { airdropWant } = require("../scripts/utils");

const name = "BBEvent-BOO";
const symbol = "BBE-BOO";
const wantAddress = "0x841FAD6EAe12c286d1Fd18d1d525DFfA75C7EFFE";
const beefyVaultAddress = "0x15DD4398721733D8273FD4Ed9ac5eadC6c018866";
const entranceFee = hre.ethers.utils.parseEther("10");
const addressWithWant = "0xD4FfFD3814D09c583D79Ee501D17F6F146aeFAC2"; //Impersonated in airdropWant
const eventLength = 100;
const rewardBase = [5000, 3000, 2000];
const rewardBaseDecimal = [0.5, 0.3, 0.2];

describe("Beefy Battles Event", () => {
    before(async () =>{
        accounts = await hre.ethers.getSigners();
        deployer = accounts[0];
        server = accounts[1];
        user = accounts[2];
        secondaryUser = accounts[3];
        thirdUser = accounts[4];
        endBlock = await (await hre.ethers.provider.getBlock("latest")).number + eventLength;

        BBEvent = await hre.ethers.getContractFactory("BeefyBattlesEventV1", deployer);
        bbEvent = await BBEvent.deploy(name, symbol, wantAddress, beefyVaultAddress, server.address, entranceFee, endBlock);

        want = await hre.ethers.getContractAt("IERC20", wantAddress);
        mooToken = await hre.ethers.getContractAt("IERC20", beefyVaultAddress);
        rewardPoolAddress = await bbEvent.getRewardPool();
        rewardPool = await hre.ethers.getContractAt("BeefyBattlesRewardPoolV1", rewardPoolAddress);

        await bbEvent.deployed();

        await airdropWant(wantAddress, user.address, hre.ethers.utils.parseEther("10"), addressWithWant);
        await airdropWant(wantAddress, secondaryUser.address, hre.ethers.utils.parseEther("10"), addressWithWant);
        await airdropWant(wantAddress, thirdUser.address, hre.ethers.utils.parseEther("10"), addressWithWant);
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

            expect(parseFloat(mooBalance)).to.greaterThan(4);
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
        before(async() =>{
            await want.connect(secondaryUser).approve(bbEvent.address, hre.ethers.utils.parseEther("10000"));
            await want.connect(thirdUser).approve(bbEvent.address, hre.ethers.utils.parseEther("10000"));
            await bbEvent.connect(secondaryUser).deposit(1);
            await bbEvent.connect(thirdUser).deposit(1);
        });
        it("Can't withdraw another user's tokenId", async () => {
            await expectRevert(bbEvent.connect(user).withdrawEarly(2), "Not the owner");
        });
        it("Gets the initial entry Fee", async () => {
            await bbEvent.connect(user).approve(bbEvent.address, 1);
            await bbEvent.connect(user).withdrawEarly(1);

            balanceOfWant = await want.balanceOf(user.address);
            balanceOfWant = hre.ethers.utils.formatEther(balanceOfWant);            
            entryFeeinEther = hre.ethers.utils.formatEther(entranceFee);

            expect(balanceOfWant).to.eq(entryFeeinEther);
        });
        it("Burns the ERC721 Ticket", async () => {
            erc721Balance = await bbEvent.balanceOf(user.address)
            expect(parseFloat(erc721Balance)).to.eq(0);
        });
        it("Every player can withdraw", async () =>{
            await bbEvent.connect(secondaryUser).approve(bbEvent.address, 2);
            await bbEvent.connect(thirdUser).approve(bbEvent.address, 3);
            await bbEvent.connect(secondaryUser).withdrawEarly(2);
            await bbEvent.connect(thirdUser).withdrawEarly(3);

            balanceOfWant = await want.balanceOf(thirdUser.address);
            balanceOfWant = hre.ethers.utils.formatEther(balanceOfWant);            
            entryFeeinEther = hre.ethers.utils.formatEther(entranceFee);

            expect(balanceOfWant).to.eq(entryFeeinEther);
        });
    });
    describe("Battle results Logic", async () =>{
        before(async () => {
            await bbEvent.connect(user).deposit(1);
            await bbEvent.connect(secondaryUser).deposit(1);
        });
        it("Can't set result if token doesn't exist", async()=>{
            await expectRevert(bbEvent.connect(server).postResult(10,5,10,0), "Token doesn't exist");
        });
        it("Sets the result", async () => {
            await bbEvent.connect(server).postResult(4,5,10,0);
            userPosition = await bbEvent.calculateLeaderboardPosition(4);
            secondaryUserPosition = await bbEvent.calculateLeaderboardPosition(5);
            expect(userPosition.toNumber()).to.eq(0);
            expect(secondaryUserPosition.toNumber()).to.eq(1);
        });
    });
    describe("Reward Pool Logic", async() =>{
        it("Owner of the Reward Pool is the same as Event's owner", async() => {
            rewardPoolOwner = await rewardPool.owner();
            bbEventOwner = await bbEvent.owner();
            expect(rewardPoolOwner).to.eq(bbEventOwner);
        });
        it("Only event can call claimRewards", async() => {
            await expectRevert(rewardPool.connect(user).claimRewards(user.address, 0, 1, 1), "Caller: not the event");
        });
        it("Sets the reward base", async() => {
            await rewardPool.connect(deployer).setRewardBase(rewardBase);
            firstPosRewardBase = await rewardPool.getRewardBase(0);
            secondPosRewardBase = await rewardPool.getRewardBase(1);
            expect(firstPosRewardBase.toNumber()).to.eq(rewardBase[0]);
            expect(secondPosRewardBase.toNumber()).to.eq(rewardBase[1]);
        });
    })
    describe("Rewards Logic", async() => {
        it("Can't harvest rewards if event hasn't ended", async () => {
            await expectRevert(bbEvent.connect(user).harvestRewards(), "EndEventBlock not reached");
        });
        it("Can't withdraw and claim before event has finished", async() => {
            await expectRevert(bbEvent.connect(user).withdrawAndClaim(4), "Event not finished");
        });
        it("Harvests rewards", async() =>{
            await hre.timeAndMine.mine(eventLength);
            await bbEvent.connect(user).harvestRewards();

            rewardPoolBalance = await want.balanceOf(await bbEvent.getRewardPool());
            rewardPoolBalance = hre.ethers.utils.formatEther(rewardPoolBalance);

            expect(parseFloat(rewardPoolBalance)).to.gt(0);
        });
        it("Calculates the rewards correctly", async () => {
            totalRewards = await rewardPool.eventRewards();
            totalRewards = hre.ethers.utils.formatEther(totalRewards);

            calculatedRewards = await rewardPool.calculateRewards(0,1,1);
            calculatedRewards = hre.ethers.utils.formatEther(calculatedRewards);
            expect(parseFloat(calculatedRewards)).to.be.closeTo(parseFloat(totalRewards) * rewardBaseDecimal[0], 1e-18);
        });
        it("Claims the rewards", async() => {
            await bbEvent.connect(user).withdrawAndClaim(4);
            userBalance = await want.balanceOf(user.address);
            entryFeeinEther = hre.ethers.utils.formatEther(entranceFee);

            expect(parseFloat(userBalance)).to.be.gt(parseFloat(entryFeeinEther));
        });
    });
    after(async() => {
        await want.connect(user).transfer(addressWithWant, await want.balanceOf(user.address));
        await want.connect(secondaryUser).transfer(addressWithWant, await want.balanceOf(secondaryUser.address));
        await want.connect(thirdUser).transfer(addressWithWant, await want.balanceOf(thirdUser.address));
    })
});