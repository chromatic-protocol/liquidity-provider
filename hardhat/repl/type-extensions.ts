// If your plugin extends types from another plugin, you should import the plugin here.

// To extend one of Hardhat's types, you need to import the module where it has been defined, and redeclare it.
import { type ChromaticLP } from '@chromatic/typechain-types'
import { type Signer } from 'ethers'
import 'hardhat-deploy'
import 'hardhat/types/runtime'
import type { LPContractMap, MarketInfo } from './types'

declare module 'hardhat/types/runtime' {
  interface HardhatRuntimeEnvironment {
    deployLP?: () => Promise<LPContractMap>
    lpAddresses?: LPContractMap
    getMarkets?: () => Promise<Array<MarketInfo>>
    connectMarketLP?: (marketAddress: string, signer?: Signer) => ChromaticLP
  }
}
