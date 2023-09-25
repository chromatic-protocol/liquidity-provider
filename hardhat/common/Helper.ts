import { ChromaticMarketFactory, Client as ClientSDK } from '@chromatic-protocol/sdk-ethers-v6'
import { Signer } from 'ethers'
import type { HardhatRuntimeEnvironment } from 'hardhat/types'
import {
  ChromaticLPRegistry,
  ChromaticLPRegistry__factory,
  ChromaticLP__factory
} from '~/typechain-types'
import { DEPLOYED, DeployedStore } from './DeployedStore'
import { MarketInfo } from './types'

export class Helper {
  sdk: ClientSDK
  deployed: DeployedStore

  static async createAsync(hre: HardhatRuntimeEnvironment, signerOrAddress: string | Signer) {
    let signer: Signer
    if (typeof signerOrAddress === 'string') {
      const signers = await hre.ethers.getSigners()
      signer = signers.find((s) => s.address === signerOrAddress)!
    } else {
      signer = signerOrAddress as Signer
    }
    console.log('signer:', signer)
    const helper = new Helper(hre, signer, await signer.getAddress())
    await helper.initialize()
    return helper
  }

  private constructor(
    public readonly hre: HardhatRuntimeEnvironment,
    public readonly signer: Signer,
    public readonly signerAddress: string
  ) {
    this.sdk = new ClientSDK(this.hre.network.name, this.signer)

    if (this.hre.network.tags.local) {
      this.deployed = DEPLOYED
    } else {
      this.deployed = new DeployedStore()
    }
  }

  private async initialize() {
    if (!this.hre.network.tags.local) {
      const deployed = await this.hre.deployments.get('ChromaticLPRegistry')
      this.deployed.saveRegistry(deployed.address)

      const registry = this.registry
      const markets = await this.markets()
      for (const market of markets) {
        const lpAddresses = await registry.lpListByMarket(market.address)
        lpAddresses.map((x) => this.deployed.saveLP(x, market.address))
      }
    }
  }

  get isLocal(): boolean {
    return this.hre.network.tags.local
  }

  get marketFactory(): ChromaticMarketFactory {
    return this.sdk.marketFactory()
  }

  get registry(): ChromaticLPRegistry {
    const address = this.deployed.registry
    if (!address) throw new Error('deployed registry not exist')
    return ChromaticLPRegistry__factory.connect(address, this.signer)
  }

  lpOfMarket(marketAddress: string) {
    const address = this.deployed.lpOfMarket(marketAddress)
    if (!address) throw new Error('no address')
    return ChromaticLP__factory.connect(address, this.signer)
  }

  async settlementTokens() {
    return await this.marketFactory.registeredSettlementTokens()
  }

  async markets(): Promise<MarketInfo[]> {
    const allMarkets = []
    const tokens = await this.settlementTokens()
    for (let token of tokens) {
      const markets = await this.marketFactory.getMarkets(token.address)
      allMarkets.push(...markets)
    }
    return allMarkets
  }

  async marketAddresses(): Promise<string[]> {
    const infos = await this.markets()
    return infos.map((x) => x.address)
  }
}
