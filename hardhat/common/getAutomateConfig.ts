import { CHAIN_ID, GELATO_ADDRESSES } from '@gelatonetwork/automate-sdk'
import { ZeroAddress } from 'ethers'
import type { HardhatRuntimeEnvironment } from 'hardhat/types'
import type { AddressType, AutomateConfig } from '~/hardhat/common/types'

export function getAutomateAddress(hre: HardhatRuntimeEnvironment): AddressType {
  if (hre.network.tags.gelato) {
    if (hre.network.tags.testnet || hre.network.tags.local) {
      return GELATO_ADDRESSES[CHAIN_ID.ARBSEPOLIA].automate as AddressType
    } else {
      return GELATO_ADDRESSES[hre.network.config.chainId!].automate as AddressType
    }
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
  } else {
    throw new Error('unknown automation type')
  }
}
