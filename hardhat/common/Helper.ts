import chalk from 'chalk'
import { Signer } from 'ethers'
import type { HardhatRuntimeEnvironment } from 'hardhat/types'
import { Contracts } from './Contracts'
import { DEPLOYED, DeployedStore } from './DeployedStore'
import { AddressType, MarketInfo } from './types'
export class Helper {
  deployed: DeployedStore
  c: Contracts

  static async createAsync(hre: HardhatRuntimeEnvironment, signerOrAddress: string | Signer) {
    let signer: Signer
    if (typeof signerOrAddress === 'string') {
      const signers = await hre.ethers.getSigners()
      signer = signers.find((s) => s.address === signerOrAddress)!
    } else {
      signer = signerOrAddress as Signer
    }
    // console.log('signer:', signer)
    const helper = new Helper(hre, signer, await signer.getAddress())
    await helper.initialize()
    return helper
  }

  private constructor(
    public readonly hre: HardhatRuntimeEnvironment,
    public readonly signer: Signer,
    public readonly signerAddress: string
  ) {
    if (this.hre.network.tags.local) {
      this.deployed = DEPLOYED
    } else {
      this.deployed = new DeployedStore()
    }
    this.c = new Contracts(hre, signer, this.deployed)
  }

  get networkName() {
    if (this.hre.network.name == 'anvil_arbitrum') {
      return 'anvil'
    } else {
      return this.hre.network.name
    }
  }

  private async initialize() {
    if (!this.hre.network.tags.local) {
      try {
        let deployed = await this.hre.deployments.get('ChromaticLPRegistry')
        if (deployed?.address) {
          this.deployed.saveRegistry(deployed.address as AddressType)
          const registry = this.c.lpRegistry
          const markets = await this.markets()
          for (const market of markets) {
            const lpAddresses = await registry.lpListByMarket(market.address)
            lpAddresses.map((x) => this.deployed.saveLP(x as AddressType, market.address))
          }
        }
        deployed = await this.hre.deployments.get('AutomateLP')
        this.deployed.saveAutomateLP(deployed.address as AddressType)

        deployed = await this.hre.deployments.get('AutomateBP')
        this.deployed.saveAutomateBP(deployed.address as AddressType)

        deployed = await this.hre.deployments.get('ChromaticBPFactory')
        this.deployed.saveBPFactory(deployed.address as AddressType)
      } catch {
        // pass
      }
    }
  }

  get isLocal(): boolean {
    return this.hre.network.tags.local
  }

  // get marketFactory(): ChromaticMarketFactory {
  //   return this.sdk.marketFactory()
  // }

  lpOfMarket(marketAddress: string, index: number) {
    const addresses = this.deployed.lpOfMarket(marketAddress as AddressType)
    if (!addresses) throw new Error('no address')
    return this.c.lp(addresses[index])
  }

  lp(lpAddress: string) {
    return this.c.lp(lpAddress)
  }

  async settlementTokens() {
    return await this.c.marketFactory.registeredSettlementTokens()
  }

  async markets(): Promise<MarketInfo[]> {
    const allMarkets = []
    const tokens = await this.settlementTokens()
    console.log(chalk.green(`✨ total ${tokens.length} settlement tokens in marketFactory`))

    for (let token of tokens) {
      const markets = await this.c.marketFactory.getMarketsBySettlmentToken(token)

      const erc20 = this.c.erc20(token)
      const name = await erc20.name()
      const symbol = await erc20.symbol()
      const decimals = await erc20.decimals()

      console.log(chalk.green(`✨ registered token of marketFactory: ${name}, ${symbol}, ${token}`))
      console.log(chalk.green(`✨ total ${markets.length} market`))

      const marketInfos = await Promise.all(
        markets.map(async (x) => {
          const market = this.c.market(x)
          const settlementToken = await market.settlementToken()
          return {
            address: x,
            settlementToken: {
              name: name,
              symbol: symbol,
              decimals: decimals,
              address: settlementToken
            }
          } as MarketInfo
        })
      )
      allMarkets.push(...marketInfos)
    }
    return allMarkets
  }

  async marketAddresses(): Promise<string[]> {
    const infos = await this.markets()
    return infos.map((x) => x.address)
  }

  get lpAddresses(): string[] {
    return this.deployed.lpAddresses
  }
}
