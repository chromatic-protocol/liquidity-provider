// If your plugin extends types from another plugin, you should import the plugin here.

// To extend one of Hardhat's types, you need to import the module where it has been defined, and redeclare it.
import { type Signer } from 'ethers'
import 'hardhat-deploy'
import 'hardhat/types/runtime'
import { DeployTool, DeployedStore, Helper } from '~/hardhat/common'
import type { MarketInfo } from '~/hardhat/common/DeployTool'

import { Client } from './Client'

declare module 'hardhat/types/runtime' {
  interface HardhatRuntimeEnvironment {
    getMarkets?: () => Promise<Array<MarketInfo>>
    getClient?: (signer?: Signer) => Promise<Client>
    getHelper?: (signer?: Signer) => Promise<Helper>
    getDeployTool?: () => Promise<DeployTool>

    lpDeployed?: DeployedStore
  }
}
