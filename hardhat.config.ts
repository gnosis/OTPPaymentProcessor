import dotenv from "dotenv";
import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";

dotenv.config();

const WALLET_MNEMONIC = process.env.WALLET_MNEMONIC;
const WALLET_PRIVATE_KEY = process.env.WALLET_PRIVATE_KEY;

let accounts;
if (WALLET_MNEMONIC) {
  accounts = { mnemonic: WALLET_MNEMONIC };
}
if (WALLET_PRIVATE_KEY) {
  accounts = [WALLET_PRIVATE_KEY];
}


const config: HardhatUserConfig = {
  solidity: "0.8.9",
  networks: {
    ledger: {
      url: "http://127.0.0.1:1248"
    },
    goerli: {
      url: process.env.JSONRPC_HTTP_URL || "http://127.0.0.1:8545",
      accounts,
    },
    opongc: {
      url: "https://optimism.gnosischain.com" || "http://127.0.0.1:8545",
      accounts,
    },
    scrolltest: {
      url: `https://prealpha.scroll.io/l2`,
      accounts,
    },
  },
};

export default config;
