import '@chromatic-protocol/hardhat-package'
import '@nomicfoundation/hardhat-ethers'
import '@nomicfoundation/hardhat-foundry'
import '@nomicfoundation/hardhat-toolbox'
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
      // localhost anvil
      forking: {
        url: `https://arb-goerli.g.alchemy.com/v2/${process.env.ALCHEMY_KEY}`,
        blockNumber: 18064747
      },
      ...common,
      accounts: {
        ...common.accounts,
        mnemonic: MNEMONIC_JUNK
      },
      tags: ['local'],
      allowUnlimitedContractSize: true,
      saveDeployments: false
    },
    anvil: {
      // localhost anvil
      ...common,
      accounts: {
        ...common.accounts,
        mnemonic: MNEMONIC_JUNK
      },
      url: 'http://127.0.0.1:8545',
      chainId: 31337,
      tags: ['local'],
      allowUnlimitedContractSize: true,
      saveDeployments: false
    },
    arbitrum_goerli: {
      // testnet
      ...common,
      url: 'https://goerli-rollup.arbitrum.io/rpc',
      chainId: 421613,
      tags: ['testnet']
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
      arbitrumGoerli: process.env.ARBISCAN_GOERLI_API_KEY!
    }
  }
}

export default config
