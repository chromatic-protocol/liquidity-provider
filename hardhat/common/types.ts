import { BigNumberish } from 'ethers'

import { DeployResult } from 'hardhat-deploy/types'
import type { IOracleProvider } from '~/typechain-types'

export interface LPConfig {
  config: {
    utilizationTargetBPS: number
    rebalanceBPS: number
    rebalnceCheckingInterval: BigNumberish
    settleCheckingInterval: BigNumberish
  }
  feeRates: Array<number>
  distributionRates: Array<number>
  automateConfig?: {
    automate: string
    opsProxyFactory: string
  }
}

export interface MarketInfo {
  address: string
  oracleValue: IOracleProvider.OracleVersionStructOutput
  description: string
}

export interface LPContractAddress {
  lpAddress: string
  logicAddress: string
}

export interface LPContractMap {
  [marketAddress: string]: LPContractAddress
}

export interface LPDeployedResultMap {
  [marketAddress: string]: DeployResult
}

export interface RegistryDeployedResultMap {
  registry?: DeployResult
}
