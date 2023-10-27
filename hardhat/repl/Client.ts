import { ChromaticMarketFactory, Client as ClientSDK } from '@chromatic-protocol/sdk-ethers-v6'
import { IERC20__factory } from '@chromatic-protocol/sdk-ethers-v6/contracts'
import type { Signer } from 'ethers'
import type { HardhatRuntimeEnvironment } from 'hardhat/types'
import { Helper } from '~/hardhat/common/Helper'
import { ChromaticLP__factory, type ChromaticLP, type IERC20 } from '~/typechain-types'
export class Client {
  public readonly client!: ClientSDK

  private helper: Helper
  private _marketAddress: string = ''
  private _settlementTokenAddress: string = ''
  private _lpAddresses: string[] = []

  private constructor(helper: Helper) {
    this.helper = helper
  }

  static async createAsync(hre: HardhatRuntimeEnvironment, signerOrAddress: string | Signer) {
    const helper = await Helper.createAsync(hre, signerOrAddress)
    const client = new Client(helper)
    await client.initialize()
    return client
  }

  private async initialize() {
    // this.helper.
  }

  get marketFactory(): ChromaticMarketFactory {
    return this.helper.marketFactory
  }

  async settlementTokens() {
    return await this.helper.settlementTokens()
  }

  async markets() {
    return await this.helper.markets()
  }

  async setCurrentMarket(marketAddress: string) {
    this._marketAddress = marketAddress
    this._settlementTokenAddress = await this.market.settlementToken()
  }

  async setCurrentLP(lpAddress: string) {
    const lp = ChromaticLP__factory.connect(lpAddress, this.signer)
    this._marketAddress = await lp.market()
    this._settlementTokenAddress = await this.market.settlementToken()
  }

  get signer(): Signer {
    return this.helper.signer
  }

  get marketAddress(): string {
    return this._marketAddress
  }
  get settlementTokenAddress(): string {
    return this._settlementTokenAddress
  }

  lpAddress(index: number): string {
    return this.helper.deployed.lpOfMarket(this._marketAddress)[index]
  }

  get market() {
    return this.client.market().contracts().market(this._marketAddress)
  }

  get settlementToken(): IERC20 {
    return IERC20__factory.connect(this._settlementTokenAddress, this.signer)
  }

  lp(index: number): ChromaticLP {
    return ChromaticLP__factory.connect(this.lpAddress(index), this.signer)
  }

  get lpAddresses(): string[] {
    return this.helper.deployed.lpAddresses
  }

  public toString = (): string => {
    return {
      market: this.marketAddress,
      settlementToken: this.settlementTokenAddress,
      chromaticLP: this.lpAddress
    }.toString()
  }
}
