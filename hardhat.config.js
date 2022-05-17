require("@nomiclabs/hardhat-ethers");
require("@nomiclabs/hardhat-etherscan");
require("@atixlabs/hardhat-time-n-mine");
require("hardhat-gas-reporter");
require('solidity-coverage');
require('dotenv').config();

module.exports = {
  defaultNetwork: "hardhat",
  networks: {
    hardhat: {
      forking: {
        url: process.env.FTM,
      }
    }
  },
  etherscan: {
    // Your API key for Etherscan
    // Obtain one at https://etherscan.io/
    apiKey: {
      kovan: process.env.ETHERSCAN_API_KEY
    }
  },
  gasReporter: {
    currency: 'USD',
    token: 'FTM',
    gasPrice: 400,
    coinmarketcap: '38344cee-5f67-479a-a2a5-708c349c548c'
  },
  solidity: {
    compilers: [
      {
        version: "0.8.10",
        settings: {
          optimizer: {
            enabled: true,
            runs: 200,
          },
        },
      },
    ],
  },
};
