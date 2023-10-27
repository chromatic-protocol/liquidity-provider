import { type DeployResult } from 'hardhat-deploy/types'
// import type { LPDeployedResultMap, RegistryDeployedResultMap } from './types'

// const REGISTRY_DEPLOYED: RegistryDeployedResultMap = {}
// const LP_DEPLOYED: LPDeployedResultMap = {}

interface MarketToLPs {
  [marketAddress: string]: string[]
}

export interface RegistryDeployedResultMap {
  registry?: DeployResult
}
export class DeployedStore {
  registryAddress: string = ''
  marketToLPs: MarketToLPs = {}

  saveRegistry(result: string) {
    this.registryAddress = result
  }
  saveLP(lpAddress: string, marketAddress: string) {
    if (!this.marketToLPs[marketAddress]) {
      this.marketToLPs[marketAddress] = [lpAddress]
    } else {
      this.marketToLPs[marketAddress].push(lpAddress)
    }
  }

  get registry() {
    return this.registryAddress
  }

  lpOfMarket(marketAddress: string) {
    return this.marketToLPs[marketAddress]
  }

  get lpAddresses() {
    const result: any = []

    return result.concat(...Object.values(this.marketToLPs))
  }
}
export const DEPLOYED = new DeployedStore()
