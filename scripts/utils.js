const hre = require("hardhat");

async function airdropWant(_wantAddrress, _toAddress, _amount, _accountWithWant) {
    await network.provider.request({method: "hardhat_impersonateAccount", params: [_accountWithWant],});
    a = hre.ethers.provider.getSigner(_accountWithWant);
    w = await hre.ethers.getContractAt("IERC20", _wantAddrress, a);
    await w.transfer(_toAddress, _amount);
}

exports.airdropWant = airdropWant;