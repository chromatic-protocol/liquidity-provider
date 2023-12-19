import { CHAIN_ID, GELATO_ADDRESSES } from '@gelatonetwork/automate-sdk'
import type { HardhatRuntimeEnvironment } from 'hardhat/types'
import type { AddressType } from '~/hardhat/common/types'

export const MATE2_AUTOMATION_ADDRESS: { [key: number]: AddressType } = {
  31337: '0xA58c89bB5a9EA4F1ceA61fF661ED2342D845441B'
  // 421614: '0xA58c89bB5a9EA4F1ceA61fF661ED2342D845441B'
  // 42161: '0xA58c89bB5a9EA4F1ceA61fF661ED2342D845441B'
}

export function getAutomateAddress(hre: HardhatRuntimeEnvironment, tag=undefined): AddressType {
  if (hre.network.tags.mate2) {
    if (hre.network.tags.testnet || hre.network.tags.local) {
      return MATE2_AUTOMATION_ADDRESS[CHAIN_ID.ARBSEPOLIA]
    } else {
      return MATE2_AUTOMATION_ADDRESS[hre.network.config.chainId!]
    }
  } else if (hre.network.tags.gelato) {
    if (hre.network.tags.testnet || hre.network.tags.local) {
      return GELATO_ADDRESSES[CHAIN_ID.ARBSEPOLIA].automate as AddressType
    } else {
      return GELATO_ADDRESSES[hre.network.config.chainId!].automate as AddressType
    }
  } else {
    throw new Error('unknown automation type')
  }
}
