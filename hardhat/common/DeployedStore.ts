import { type DeployResult } from 'hardhat-deploy/types'
// import type { LPDeployedResultMap, RegistryDeployedResultMap } from './types'

// const REGISTRY_DEPLOYED: RegistryDeployedResultMap = {}
// const LP_DEPLOYED: LPDeployedResultMap = {}

interface MarketToLP {
  [marketAddress: string]: string
}

export interface RegistryDeployedResultMap {
  registry?: DeployResult
}
export class DeployedStore {
  registryAddress: string = ''
  marketToLP: MarketToLP = {}

  saveRegistry(result: string) {
    this.registryAddress = result
  }
  saveLP(lpAddress: string, marketAddress: string) {
    this.marketToLP[marketAddress] = lpAddress
  }

  get registry() {
    return this.registryAddress
  }

  lpOfMarket(marketAddress: string) {
    return this.marketToLP[marketAddress]
  }

  get lpAddresses() {
    return Object.values(this.marketToLP)
  }
}

export const DEPLOYED = new DeployedStore()
