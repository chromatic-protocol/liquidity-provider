import { BigNumberish } from 'ethers'

import { DeployResult } from 'hardhat-deploy/types'
import type { IOracleProvider } from '~/typechain-types'

export type AddressType = `0x${string}`

export type AutomateConfig =
  | {
      automate: AddressType
      opsProxyFactory: AddressType
    }
  | AddressType

export interface LPConfig {
  meta: {
    lpName?: string
    tag?: string
  }
  config: {
    utilizationTargetBPS: number
    rebalanceBPS: number
    rebalanceCheckingInterval: BigNumberish
    automationFeeReserved: BigNumberish
    minHoldingValueToRebalance: BigNumberish
  }
  feeRates: Array<number>
  distributionRates: Array<number>
  automateConfig?: AddressType
  initialLiquidity?: BigNumberish
}

export interface SettlementToken {
  name: string
  address: AddressType
  decimals: bigint
}
export interface MarketInfo {
  address: AddressType
  oracleValue: IOracleProvider.OracleVersionStructOutput
  description: string
  settlementToken: SettlementToken
}

export interface LPContractAddress {
  lpAddress: AddressType
  logicAddress: AddressType
}

export interface LPContractMap {
  [marketAddress: AddressType]: LPContractAddress
}

export interface LPDeployedResultMap {
  [marketAddress: AddressType]: DeployResult[]
}

export interface RegistryDeployedResultMap {
  registry?: DeployResult
}

export interface BPConfig {
  lp: AddressType
  minRaisingTarget: bigint
  maxRaisingTarget: bigint
  startTimeOfWarmup: bigint
  durationOfWarmup: bigint
  durationOfLockup: bigint
}
