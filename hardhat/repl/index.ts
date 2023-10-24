import { extendEnvironment } from 'hardhat/config'
import { lazyFunction, lazyObject } from 'hardhat/plugins'

import type { HardhatRuntimeEnvironment } from 'hardhat/types'

import { type Signer } from 'ethers'
import { DEPLOYED, DeployTool, Helper, getLPClient, getSDKClient } from '~/hardhat/common'
import type { LPConfig } from '~/hardhat/common/DeployTool'
import { Client } from './Client'

const LP_CONFIG: LPConfig = {
  meta: {
    lpName: 'normal',
    tag: 'N'
  },
  config: {
    utilizationTargetBPS: 5000,
    rebalanceBPS: 500,
    rebalanceCheckingInterval: 1 * 60 * 60, // 1 hours
    settleCheckingInterval: 1 * 60, // 1 minutes
    automationFeeReserved: 10 ** 18
  },
  feeRates: [-4, -3, -2, -1, 1, 2, 3, 4],
  distributionRates: [2000, 1500, 1000, 500, 500, 1000, 1500, 2000]
}

extendEnvironment((hre: HardhatRuntimeEnvironment) => {
  hre.getMarkets = lazyFunction(() => async () => {
    const helper = await Helper.createAsync(hre, (await hre.ethers.getSigners())[0])
    return await helper.markets()
  })

  hre.getClient = lazyFunction(() => async (signer?: Signer) => {
    if (!signer) {
      signer = (await hre.ethers.getSigners())[0]
    }
    return await Client.createAsync(hre, signer)
  })

  hre.getHelper = lazyFunction(() => async (signer?: Signer) => {
    if (!signer) {
      signer = (await hre.ethers.getSigners())[0]
    }
    return await Helper.createAsync(hre, signer)
  })

  hre.getDeployTool = lazyFunction(() => async () => {
    const tool = await DeployTool.createAsync(hre, LP_CONFIG)
    return tool
  })

  hre.getSDKClient = lazyFunction(() => async () => {
    return await getSDKClient(hre)
  })

  hre.getLPClient = lazyFunction(() => async () => {
    return await getLPClient(hre)
  })

  hre.lpDeployed = lazyObject(() => DEPLOYED)
})
