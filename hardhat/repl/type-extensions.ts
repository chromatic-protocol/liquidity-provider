// If your plugin extends types from another plugin, you should import the plugin here.

// To extend one of Hardhat's types, you need to import the module where it has been defined, and redeclare it.
import type {
  DeployTool,
  LPDeployedResultMap,
  MarketInfo
} from '@chromatic/hardhat/common/DeployTool'
import { type ChromaticLP } from '@chromatic/typechain-types'
import { type Signer } from 'ethers'
import 'hardhat-deploy'
import 'hardhat/types/runtime'
import { Client } from './Client'

declare module 'hardhat/types/runtime' {
  interface HardhatRuntimeEnvironment {
    deployLP?: () => Promise<LPDeployedResultMap>
    deployed?: LPDeployedResultMap
    getMarkets?: () => Promise<Array<MarketInfo>>
    connectMarketLP?: (marketAddress: string, signer?: Signer) => ChromaticLP
    getClient?: (signer?: Signer) => Promise<Client>
    getDeployTool?: () => Promise<DeployTool>
  }
}
