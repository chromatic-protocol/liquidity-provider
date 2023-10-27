import chalk from 'chalk'
import type { HardhatRuntimeEnvironment } from 'hardhat/types'

import { DeployOptions, DeployResult } from 'hardhat-deploy/types'
import { DEPLOYED } from '~/hardhat/common/DeployedStore'
import { Helper } from '~/hardhat/common/Helper'
import { ChromaticLPRegistry } from '~/typechain-types'

import { getDefaultLPConfigs } from '~/hardhat/common/LPConfig'
import { getAutomateConfig } from './getAutomateConfig'
import type { AutomateConfig, LPConfig, LPDeployedResultMap, MarketInfo } from './types'

export type * from './types'
export type AutomateType = 'gelato' | 'mate2'
export class DeployTool {
  constructor(
    public readonly hre: HardhatRuntimeEnvironment,
    public readonly helper: Helper,
    public readonly defaultLPConfigs: LPConfig[]
  ) {}
  async initialize() {}

  static async createAsync(hre: HardhatRuntimeEnvironment, defaultLPConfigs?: LPConfig[]) {
    const { deployer } = await hre.getNamedAccounts()
    const helper = await Helper.createAsync(hre, deployer)
    defaultLPConfigs = defaultLPConfigs === undefined ? getDefaultLPConfigs() : defaultLPConfigs
    const tool = new DeployTool(hre, helper, defaultLPConfigs)
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

    console.log(chalk.yellow(`✨ Deploying... ${name}\n deployOptions:`), options)
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
    const result = await this.deployAllLP(this.defaultLPConfigs)
    for (let deployed of [].concat(...Object.values(result))) {
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
    if (this.automateType == 'gelato') return 'ChromaticLPLogic'
    else {
      throw new Error('unknown automateType')
    }
  }

  get lpContractName() {
    if (this.automateType == 'gelato') return 'ChromaticLP'
    else {
      throw new Error('unknown automateType')
    }
  }

  async deployAllLP(lpConfigs?: LPConfig[]): Promise<LPDeployedResultMap> {
    const markets = await this.getMarkets()
    lpConfigs = lpConfigs == undefined ? this.defaultLPConfigs : lpConfigs
    const lpDeployed: LPDeployedResultMap = {}
    const deployedResults = []
    for (let market of markets) {
      for (let lpConfig of lpConfigs) {
        const config = this.getLPConfig(lpConfig)

        const deployed = await this.deployLP(market.address, config)
        deployedResults.push(deployed)
      }

      lpDeployed[market.address] = deployedResults
    }
    return lpDeployed
  }

  getLPConfig(lpConfig: LPConfig): LPConfig {
    let config = {
      ...lpConfig,
      automateConfig: this.automateConfig
    }
    return config
  }

  async deployLP(marketAddress: string, lpConfig: LPConfig): Promise<DeployResult> {
    console.log(chalk.green(`✨ deploying LP for market: ${marketAddress}`))
    const config = this.getLPConfig(lpConfig)
    if (!config.meta?.lpName) throw new Error('lpName not found')
    if (!config.meta?.tag) throw new Error('lp-tag not found')

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

  async registerAllLP() {
    let registry = await this.getRegistry()

    if (!this.hre.network.name.startsWith('anvil')) throw new Error('local network only')
    for (const lpAddress of this.helper.lpAddresses) {
      await this.registerLP(lpAddress, registry)
    }
  }

  async unregisterAllLP() {
    let registry = await this.getRegistry()

    for (const lpAddress of this.helper.lpAddresses) {
      await this.unregisterLP(lpAddress, registry)
    }
  }

  async cancelRebalanceTaskAll() {
    for (const lpAddress of this.helper.lpAddresses) {
      await this.cancelRebalanceTask(lpAddress)
    }
  }

  async registerLP(lpAddress: string, registry?: ChromaticLPRegistry) {
    if (!registry) registry = await this.getRegistry()

    console.log(chalk.green(`✨ registering lpAddress to registry: ${lpAddress}`))
    await (await registry.register(lpAddress)).wait()
  }

  async unregisterLP(lpAddress: string, registry?: ChromaticLPRegistry) {
    if (!registry) registry = await this.getRegistry()
    await (await registry.unregister(lpAddress)).wait()
  }

  async verify(options: any) {
    // FIXME
    if (!this.hre.network.tags.local && !this.hre.network.tags.mantle) {
      try {
        await this.hre.run('verify:verify', options)
      } catch (e) {
        console.error(e)
      }
    }
  }

  async createRebalanceTaskAll() {
    for (let lpAddress of this.helper.lpAddresses) {
      await this.createRebalanceTask(lpAddress)
    }
  }

  async createRebalanceTask(lpAddress: string) {
    const lp = this.helper.lp(lpAddress)
    console.log(chalk.yellow(`🔧 createRebalanceTask...: ${lpAddress}`))
    await (await lp.createRebalanceTask()).wait()
  }

  async cancelRebalanceTask(lpAddress: string) {
    const lp = this.helper.lp(lpAddress)
    console.log(chalk.yellow(`🔧 cancelRebalanceTask...: ${lpAddress}`))
    await (await lp.cancelRebalanceTask()).wait()
  }

  async registerAutomationAllLP() {
    for (let lpAddress of this.helper.lpAddresses) {
      await this.addWhitelistedRegistrar(lpAddress)
    }
  }
  async unregisterAutomationAllLP() {
    for (let lpAddress of this.helper.lpAddresses) {
      await this.removeWhitelistedRegistrar(lpAddress)
    }
  }

  async addWhitelistedRegistrar(lpAddress: string) {
    const mate2Registry = this.helper.automationRegistry
    console.log(chalk.yellow(`🔧 addWhitelistedRegistrar...: ${lpAddress}`))
    await (await mate2Registry.addWhitelistedRegistrar(lpAddress)).wait()
  }

  async removeWhitelistedRegistrar(lpAddress: string) {
    const mate2Registry = this.helper.automationRegistry
    console.log(chalk.yellow(`🔧 removeWhitelistedRegistrar...: ${lpAddress}`))
    await (await mate2Registry.removeWhitelistedRegistrar(lpAddress)).wait()
  }
}
