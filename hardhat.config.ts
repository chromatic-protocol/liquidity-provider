import '@nomicfoundation/hardhat-ethers'
import '@nomicfoundation/hardhat-foundry'
import '@nomicfoundation/hardhat-toolbox'
import '@nomicfoundation/hardhat-toolbox-viem'
import * as dotenv from 'dotenv'

import 'hardhat-contract-sizer'
import 'hardhat-deploy'
import type { HardhatUserConfig } from 'hardhat/config'
import 'solidity-docgen'
import 'tsconfig-paths/register'

dotenv.config()

const MNEMONIC_JUNK = 'test test test test test test test test test test test junk'

const common = {
  accounts: {
    mnemonic: process.env.MNEMONIC || MNEMONIC_JUNK,
    count: 10
  }
}

const localCommon = {
  ...common,
  accounts: {
    ...common.accounts,
    mnemonic: MNEMONIC_JUNK
  },
  allowUnlimitedContractSize: true,
  saveDeployments: false,
  timeout: 100_000 // TransactionExecutionError: Headers Timeout Error
}

const config: HardhatUserConfig = {
  solidity: {
    compilers: [
      {
        version: '0.8.19',
        settings: {
          optimizer: {
            enabled: true,
            runs: 30000
          }
        }
      }
    ]
  },
  defaultNetwork: 'hardhat',
  networks: {
    hardhat: {
      ...localCommon,
      forking: {
        url: `https://arb-sepolia.g.alchemy.com/v2/${process.env.ALCHEMY_KEY}`,
        blockNumber: 2618307
      },
      tags: ['local', 'arbitrum', 'mate2']
    },
    anvil_arbitrum: {
      ...localCommon,
      url: 'http://127.0.0.1:8545',
      chainId: 31337,
      tags: ['local', 'arbitrum', 'mate2']
    },
    arbitrum_sepolia: {
      // testnet
      ...common,
      url: `https://arb-sepolia.g.alchemy.com/v2/${process.env.ALCHEMY_KEY}`,
      chainId: 421614,
      tags: ['testnet', 'arbitrum', 'mate2']
    },
    arbitrum_one: {
      // mainnet
      ...common,
      url: `https://arb-mainnet.g.alchemy.com/v2/${process.env.ALCHEMY_KEY}`,
      chainId: 42161,
      tags: ['mainnet', 'arbitrum', 'mate2']
    }
  },
  namedAccounts: {
    deployer: {
      default: 0
    },
    gelato: 1,
    alice: 2,
    bob: 3,
    charlie: 4,
    david: 5,
    eve: 6,
    frank: 7,
    grace: 8,
    heidi: 9
  },
  etherscan: {
    apiKey: {
      arbitrumOne: process.env.ARBISCAN_API_KEY!,
      arbitrumSepolia: process.env.ARBISCAN_API_KEY!
    },
    customChains: [
      {
        network: 'arbitrumSepolia',
        chainId: 421614,
        urls: {
          apiURL: 'https://api-sepolia.arbiscan.io/api',
          browserURL: 'https://sepolia.arbiscan.io/'
        }
      }
    ]
  }
}

export default config
