import { CHAIN_ID, GELATO_ADDRESSES } from '@gelatonetwork/automate-sdk'
import type { HardhatRuntimeEnvironment } from 'hardhat/types'
import type { AddressType } from '~/hardhat/common/types'

export const MATE2_AUTOMATION_ADDRESS: { [key: number]: AddressType } = {
  421614: '0x14cC9A5B88425d357AEca1B13B8cd6F81388Fe86'  // arbitrum_sepolia
  // 42161: '0x14cC9A5B88425d357AEca1B13B8cd6F81388Fe86' // FIXME arbitrum mainnet
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
