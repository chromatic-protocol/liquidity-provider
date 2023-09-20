import { ChromaticMarketFactory, Client as ClientSDK } from '@chromatic-protocol/sdk-ethers-v6'
import { IERC20__factory } from '@chromatic-protocol/sdk-ethers-v6/contracts'
import type { Signer } from 'ethers'
import type { HardhatRuntimeEnvironment } from 'hardhat/types'
import { ChromaticLP__factory, type ChromaticLP, type IERC20 } from '~/typechain-types'

export class Client {
  public readonly client!: ClientSDK

  private _marketAddress: string
  private _settlementTokenAddress: string

  constructor(public readonly hre: HardhatRuntimeEnvironment, public readonly signer: Signer) {
    this.client = new ClientSDK(this.hre.network.name, this.signer)
    this._marketAddress = ''
    this._settlementTokenAddress = ''
  }

  get marketFactory(): ChromaticMarketFactory {
    return this.client.marketFactory()
  }

  async getSettlementTokens() {
    return await this.marketFactory.registeredSettlementTokens()
  }

  async getMarkets() {
    const allMarkets = []
    const tokens = await this.getSettlementTokens()
    for (let token of tokens) {
      const markets = await this.marketFactory.getMarkets(token.address)
      allMarkets.push(...markets)
    }
    return allMarkets
  }

  async setMarket(marketAddress: string) {
    this._marketAddress = marketAddress
    const address = await this.market.settlementToken()
    this._settlementTokenAddress = address
  }

  async signerAddress(): Promise<string> {
    return this.signer.getAddress()
  }

  get marketAddress(): string {
    return this._marketAddress
  }
  get settlementTokenAddress(): string {
    return this._settlementTokenAddress
  }

  get lpAddresses(): string[] {
    // FIXME check network
    return Object.values(this.hre.lpDeployed!).map((x) => x.address)
  }

  get lpAddress(): string {
    // FIXME check network
    return this.hre.lpDeployed![this._marketAddress].address
  }

  get market() {
    return this.client.market().contracts().market(this._marketAddress)
  }

  get settlementToken(): IERC20 {
    return IERC20__factory.connect(this._settlementTokenAddress, this.signer)
  }

  get lp(): ChromaticLP {
    return ChromaticLP__factory.connect(this.lpAddress, this.signer)
  }

  public toString = (): string => {
    return {
      market: this.marketAddress,
      settlementToken: this.settlementTokenAddress,
      chromaticLP: this.lpAddress
    }.toString()
  }
}
