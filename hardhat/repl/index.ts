import { extendEnvironment } from 'hardhat/config'
import { lazyFunction, lazyObject } from 'hardhat/plugins'

import type { HardhatRuntimeEnvironment } from 'hardhat/types'

import { type Signer } from 'ethers'
import { DEPLOYED, DeployTool, getLPClient, getSDKClient, Helper } from '~/hardhat/common'
import { getDefaultLPConfigs } from '~/hardhat/common/LPConfig'
import { Client } from './Client'

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
    const tool = await DeployTool.createAsync(hre, getDefaultLPConfigs())
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
