import { type DeployResult } from 'hardhat-deploy/types'
import { AddressType } from '~/hardhat/common/types'

interface MarketToLPs {
  [marketAddress: AddressType]: AddressType[]
}

export interface RegistryDeployedResultMap {
  registry?: DeployResult
}
export class DeployedStore {
  registryAddress?: AddressType
  bpFactoryAddress?: AddressType
  automateBP?: AddressType
  automateLP?: AddressType
  marketToLPs: MarketToLPs = {}

  saveRegistry(registryAddress: AddressType) {
    this.registryAddress = registryAddress
  }
  saveAutomateLP(automateAddress: AddressType) {
    this.automateLP = automateAddress
  }
  saveAutomateBP(automateAddress: AddressType) {
    this.automateBP = automateAddress
  }

  saveLP(lpAddress: AddressType, marketAddress: AddressType) {
    if (!this.marketToLPs[marketAddress]) {
      this.marketToLPs[marketAddress] = [lpAddress]
    } else {
      this.marketToLPs[marketAddress].push(lpAddress)
    }
  }
  saveBPFactory(result: AddressType) {
    this.bpFactoryAddress = result
  }

  get registry() {
    return this.registryAddress
  }
  get bpFactory() {
    return this.bpFactoryAddress
  }

  lpOfMarket(marketAddress: AddressType) {
    return this.marketToLPs[marketAddress]
  }

  get lpAddresses() {
    const result: AddressType[] = []

    return result.concat(...Object.values(this.marketToLPs))
  }
}
export const DEPLOYED = new DeployedStore()
