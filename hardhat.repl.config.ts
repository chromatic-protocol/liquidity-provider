import config from './hardhat.config'
import './hardhat/repl'

const MNEMONIC_JUNK = 'test test test test test test test test test test test junk'

const hardhatConfig = {
  ...config,
  networks: {
    ...config.networks,
    anvil_arbitrum: {
      // localhost anvil_arbitrum
      ...config.networks?.anvil_arbitrum,
      accounts: {
        mnemonic: process.env.MNEMONIC || MNEMONIC_JUNK
      }
    },
    anvil_mantle: {
      // localhost anvil_mantle
      ...config.networks?.anvil_mantle,
      accounts: {
        mnemonic: process.env.MNEMONIC || MNEMONIC_JUNK
      }
    }
  }
}

export default hardhatConfig
