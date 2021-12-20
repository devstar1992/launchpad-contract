import "@nomiclabs/hardhat-web3";
import "@nomiclabs/hardhat-ethers";
import "hardhat-tracer";
import { task } from "hardhat/config";
require("dotenv").config();


/**
 * @type import('hardhat/config').HardhatUserConfig
 */
module.exports = {
  solidity: {
    version: "0.8.0",
    settings: {
      optimizer: {
        enabled: true,
        runs: 200,
      },
    },
  },
  networks: {
    ropsten: {
      url: process.env.NETWORK_GATEWAY_API,
      accounts: [
        process.env.POOL_OWNER_PRIMARY_KEY,
        process.env.DEPLOYER_PRIMARY_KEY,
        process.env.RAISED_WEI_RECEIVER_PRIMARY_KEY,
      ],
    },
  },
  // defaultNetwork: "localhost",
};
