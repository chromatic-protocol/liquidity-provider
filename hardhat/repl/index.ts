import { extendEnvironment } from 'hardhat/config'
import { lazyFunction, lazyObject } from 'hardhat/plugins'

import type { HardhatRuntimeEnvironment } from 'hardhat/types'

import { type ChromaticLP } from '@chromatic/typechain-types'
import { type Signer } from 'ethers'
import { connectChromaticLP, deployLP, getMarkets } from './utils'
import { LPConfig, LPContractMap } from './types'

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

const LP_DEPLOYED: LPContractMap = {}

extendEnvironment((hre: HardhatRuntimeEnvironment) => {
  hre.deployLP = lazyFunction(() => async (): Promise<LPContractMap> => {
    const result = await deployLP(hre, LP_CONFIG)

    for (const [marketAddress, value] of Object.entries(result)) {
      LP_DEPLOYED[marketAddress] = value
    }
    return result
  })

  hre.lpAddresses = lazyObject(() => LP_DEPLOYED)
  hre.getMarkets = lazyFunction(() => async () => {
    return await getMarkets(hre)
  })

  hre.connectMarketLP = lazyFunction(
    () =>
      (marketAddress: string, signer?: Signer): ChromaticLP => {
        return connectChromaticLP(LP_DEPLOYED[marketAddress].lpAddress, signer)
      }
  )
})
