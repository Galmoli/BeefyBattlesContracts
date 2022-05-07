const hre = require("hardhat");
const { expect } = require("chai");
const { expectRevert } = require("@openzeppelin/test-helpers");
const { airdropWant } = require("../scripts/utils");

const name = "BBEvent-DAI";
const symbol = "BBE-DAI";
const wantAddress = "0x8D11eC38a3EB5E956B052f67Da8Bdc9bef8Abf3E";
const beefyVaultAddress = "0x920786cff2A6f601975874Bb24C63f0115Df7dc8";
const entranceFee = hre.ethers.utils.parseEther("10");

describe("Beefy Battles Event", () => {
    before(async () =>{
        accounts = await hre.ethers.getSigners();
        deployer = accounts[0];
        server = accounts[1];
        user = accounts[2];

        BBEvent = await hre.ethers.getContractFactory("BeefyBattlesEventV1", deployer);
        bbEvent = await BBEvent.deploy(name, symbol, wantAddress, beefyVaultAddress, server.address, entranceFee);

        await bbEvent.deployed();
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

        });
        it("Deposit want", async () => {

        });
        it("Receives ERC721 Ticket", async () => {

        });
        it("Can't deposit twice in event", async () => {

        });
    });
})