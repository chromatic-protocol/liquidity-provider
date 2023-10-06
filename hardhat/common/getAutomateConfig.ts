import { CHAIN_ID, GELATO_ADDRESSES } from '@gelatonetwork/automate-sdk'
import { ZeroAddress } from 'ethers'
import type { HardhatRuntimeEnvironment } from 'hardhat/types'
import type { AddressType, AutomateConfig } from '~/hardhat/common/types'

export const MATE2_AUTOMATION_ADDRESS: { [key: number]: AddressType } = {
  31338: '0xA58c89bB5a9EA4F1ceA61fF661ED2342D845441B', // anvil_mantle
  5001: '0xF4564c2310680c4F19f2625842E3875A98c110A3' // mantle_testnet
}

function getAutomateAddress(hre: HardhatRuntimeEnvironment): AddressType {
  if (hre.network.tags.gelato) {
    if (hre.network.tags.testnet || hre.network.tags.local) {
      return GELATO_ADDRESSES[CHAIN_ID.ARBITRUM_GOERLI].automate as AddressType
    } else {
      return GELATO_ADDRESSES[hre.network.config.chainId!].automate as AddressType
    }
  } else if (hre.network.tags.mate2) {
    return MATE2_AUTOMATION_ADDRESS[hre.network.config.chainId!]
  } else {
    throw new Error('unknown automation type')
  }
}

export function getAutomateConfig(hre: HardhatRuntimeEnvironment): AutomateConfig {
  if (hre.network.tags.gelato) {
    return {
      automate: getAutomateAddress(hre),
      opsProxyFactory: ZeroAddress as AddressType
    }
  } else if (hre.network.tags.mate2) {
    return getAutomateAddress(hre)
  } else {
    throw new Error('unknown automation type')
  }
}
