import chalk from 'chalk'
import type { HardhatRuntimeEnvironment } from 'hardhat/types'

import { DeployOptions, DeployResult } from 'hardhat-deploy/types'
import { DEPLOYED } from '~/hardhat/common/DeployedStore'
import { Helper } from '~/hardhat/common/Helper'
import { ChromaticLPRegistry } from '~/typechain-types'

import { getAutomateConfig } from './getAutomateConfig'
import type { AutomateConfig, LPConfig, LPDeployedResultMap, MarketInfo } from './types'

export type * from './types'
export type AutomateType = 'gelato' | 'mate2'
export class DeployTool {
  constructor(
    public readonly hre: HardhatRuntimeEnvironment,
    public readonly helper: Helper,
    public readonly defaultLPConfig?: LPConfig
  ) {}
  async initialize() {}

  static async createAsync(hre: HardhatRuntimeEnvironment, defaultLPConfig?: LPConfig) {
    const { deployer } = await hre.getNamedAccounts()
    const helper = await Helper.createAsync(hre, deployer)
    const tool = new DeployTool(hre, helper, defaultLPConfig)
    await tool.initialize()
    return tool
  }

  get deployer() {
    return this.helper.signerAddress
  }
  get signer() {
    return this.helper.signer
  }
  get sdk() {
    return this.helper.sdk
  }

  private get _deploy() {
    return this.hre.deployments.deploy
  }

  private async deploy(name: string, options: DeployOptions): Promise<DeployResult> {
    if (!this.deployer) throw new Error('not initialized')

    console.log(chalk.yellow(`✨ Deploying... ${name}\n deployOptions: ${JSON.stringify(options)}`))
    const deployResult = await this._deploy(name, options)

    if (deployResult.newlyDeployed) {
      console.log(chalk.blue(`✨ newly deployed ${name}: ${deployResult.address}\n`))
    } else {
      console.log(chalk.green(`✨ previously deployed ${name}: ${deployResult.address}\n`))
    }

    return deployResult
  }

  async deployAll() {
    await this.deployRegistry()
    const result = await this.deployAllLP(this.defaultLPConfig)
    for (let deployed of Object.values(result)) {
      await this.registerLP(deployed.address)
    }
  }

  async deployRegistry(): Promise<DeployResult> {
    const factory = this.helper.marketFactory.contracts().marketFactory
    const factoryAddress = await factory.getAddress()
    console.log(`factoryAddress: ${factoryAddress}`)

    const res = await this.deploy('ChromaticLPRegistry', {
      from: this.deployer,
      args: [factoryAddress]
    })

    DEPLOYED.saveRegistry(res.address)
    await this.verify({ address: res.address, constructorArguments: [factoryAddress] })

    return res
  }

  get automateType(): AutomateType | undefined {
    if (this.hre.network.tags.gelato) return 'gelato'
    else if (this.hre.network.tags.mate2) return 'mate2'
    else return undefined
  }

  get automateConfig(): AutomateConfig {
    return getAutomateConfig(this.hre)
  }

  get lpLogicContractName() {
    if (this.automateType == 'gelato') return 'ChromaticLPLogicGelato'
    else if (this.automateType == 'mate2') return 'ChromaticLPLogicMate2'
    else {
      throw new Error('unknown automateType')
    }
  }

  get lpContractName() {
    if (this.automateType == 'gelato') return 'ChromaticLPGelato'
    else if (this.automateType == 'mate2') return 'ChromaticLPMate2'
    else {
      throw new Error('unknown automateType')
    }
  }

  async deployAllLP(lpConfig?: LPConfig) {
    const config = this.getLPConfig(lpConfig)

    const markets = await this.getMarkets()

    const lpDeployed: LPDeployedResultMap = {}
    for (let market of markets) {
      const deployed = await this.deployLP(market.address, config)

      lpDeployed[market.address] = deployed
    }
    return lpDeployed
  }

  getLPConfig(lpConfig?: LPConfig): LPConfig {
    let config: LPConfig
    if (lpConfig == undefined) {
      if (this.defaultLPConfig != undefined) {
        config = { ...this.defaultLPConfig }
      } else {
        throw new Error('undefined LPConfig')
      }
    } else {
      config = lpConfig
    }
    config.automateConfig = this.automateConfig
    return config
  }

  async deployLP(marketAddress: string, lpConfig?: LPConfig): Promise<DeployResult> {
    console.log(chalk.green(`✨ deploying LP for market: ${marketAddress}`))
    const config = this.getLPConfig(lpConfig)
    if (!config.meta?.lpName) throw new Error('lpName not found')

    const { address: logicAddress } = await this.deploy(this.lpLogicContractName, {
      from: this.deployer,
      args: [config.automateConfig]
    })
    const args = [
      logicAddress,
      config.meta,
      {
        market: marketAddress,
        ...config.config
      },
      config.feeRates,
      config.distributionRates,
      config.automateConfig
    ]
    const result = await this.deploy(this.lpContractName, {
      from: this.deployer,
      args: args
    })
    await this.verify({ address: result.address, constructorArguments: args })

    DEPLOYED.saveLP(result.address, marketAddress)

    return result
  }

  async getMarkets(): Promise<MarketInfo[]> {
    const marketFactory = this.sdk.marketFactory()

    const allMarkets = []
    const tokens = await marketFactory.registeredSettlementTokens()
    // console.log(chalk.green(`✨ registered tokens of marketFactory: ${tokens}`))
    if (tokens.length == 0) {
      throw new Error('settlementToken not found')
    }

    for (let token of tokens) {
      console.log(
        chalk.green(`✨ registered token of marketFactory: ${token.name}, ${token.address}`)
      )
      const markets = await marketFactory.getMarkets(token.address)
      allMarkets.push(...markets)
    }

    return allMarkets as MarketInfo[]
  }

  async getRegistry() {
    const registryDeployed = this.helper.deployed.registryAddress
    if (!registryDeployed) throw new Error('registry not found')
    return this.helper.registry
  }

  async registerLPAll() {
    let registry = await this.getRegistry()

    if (!this.hre.network.name.startsWith('anvil')) throw new Error('local network only')
    for (const lpAddress of DEPLOYED.lpAddresses) {
      this.registerLP(lpAddress, registry)
    }
  }

  async registerLP(lpAddress: string, registry?: ChromaticLPRegistry) {
    if (!registry) registry = await this.getRegistry()

    console.log(chalk.green(`✨ registering lpAddress to registry: ${lpAddress}`))
    await registry.register(lpAddress)
  }

  async unregisterLP(lpAddress: string, registry?: ChromaticLPRegistry) {
    if (!registry) registry = await this.getRegistry()
    await registry.unregister(lpAddress)
  }

  async verify(options: any) {
    if (!this.hre.network.tags.local) {
      try {
        await this.hre.run('verify:verify', options)
      } catch (e) {
        console.error(e)
      }
    }
  }
}
