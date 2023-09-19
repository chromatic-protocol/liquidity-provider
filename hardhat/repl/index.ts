import { extendEnvironment } from 'hardhat/config'
import { lazyFunction, lazyObject } from 'hardhat/plugins'

import type { HardhatRuntimeEnvironment } from 'hardhat/types'

import type { LPConfig, LPDeployedResultMap } from '@chromatic/hardhat/common/DeployTool'
import { DeployTool } from '@chromatic/hardhat/common/DeployTool'
import { type Signer } from 'ethers'
import { Client } from './Client'

const LP_CONFIG: LPConfig = {
  config: {
    utilizationTargetBPS: 5000,
    rebalanceBPS: 500,
    rebalnceCheckingInterval: 1 * 60 * 60, // 1 hours
    settleCheckingInterval: 1 * 60 // 1 minutes
  },
  feeRates: [-4, -3, -2, -1, 1, 2, 3, 4],
  distributionRates: [2000, 1500, 1000, 500, 500, 1000, 1500, 2000]
}

const LP_DEPLOYED: LPDeployedResultMap = {}

extendEnvironment((hre: HardhatRuntimeEnvironment) => {
  hre.deployLP = lazyFunction(() => async (): Promise<LPDeployedResultMap> => {
    const tool = await DeployTool.createAsync(hre, LP_CONFIG)
    const result = await tool.deployAllLP()

    // for (const [marketAddress, value] of Object.entries(result)) {
    //   LP_DEPLOYED[marketAddress] = value
    // }
    return result
  })

  hre.lpAddresses = lazyObject(() => LP_DEPLOYED)
  hre.getMarkets = lazyFunction(() => async () => {
    const tool = await DeployTool.createAsync(hre, LP_CONFIG)
    const result = await tool.getMarkets()
    return result
  })

  hre.getClient = lazyFunction(() => async (signer?: Signer) => {
    if (!signer) {
      signer = (await hre.ethers.getSigners())[0]
    }
    return new Client(hre, signer)
  })

  hre.getDeployTool = lazyFunction(() => async () => {
    const tool = await DeployTool.createAsync(hre, LP_CONFIG)
    return tool
  })
})
