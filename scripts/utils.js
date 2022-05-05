const hre = require("hardhat");

async function airdropWant(_wantAddrress, _toAddress, _amount, _impersonateAddress) {
    a = hre.ethers.provider.getSigner(_impersonateAddress);
    w = await hre.ethers.getContractAt("IERC20", _wantAddrress, a);
    await w.transfer(_toAddress, _amount);
}

exports.airdropWant = airdropWant;