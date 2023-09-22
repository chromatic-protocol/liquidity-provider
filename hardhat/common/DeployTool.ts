import { GELATO_ADDRESSES } from '@gelatonetwork/automate-sdk'
import chalk from 'chalk'
import { ZeroAddress } from 'ethers'
import type { HardhatRuntimeEnvironment } from 'hardhat/types'

import { DeployOptions, DeployResult } from 'hardhat-deploy/types'
import { DEPLOYED } from '~/hardhat/common/DeployedStore'
import { Helper } from '~/hardhat/common/Helper'
import { ChromaticLPRegistry } from '~/typechain-types'

import type { LPConfig, LPDeployedResultMap, MarketInfo } from './types'
export type * from './types'

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

  async deploy(name: string, options: DeployOptions): Promise<DeployResult> {
    if (!this.deployer) throw new Error('not initialized')

    console.log(chalk.yellow(`✨ Deploying... ${name}`))
    const deployResult = await this._deploy(name, options)

    if (deployResult.newlyDeployed) {
      console.log(chalk.yellow(`✨ newly deployed ${name}: ${deployResult.address}\n`))
    } else {
      console.log(chalk.green(`✨ previously deployed ${name}: ${deployResult.address}\n`))
    }

    return deployResult
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

  get echainId() {
    const { config, network } = this.hre
    const echainId =
      network.name === 'anvil' ? config.networks.arbitrum_goerli.chainId! : network.config.chainId!
    return echainId
  }

  getAutomateConfig(): {
    automate: string
    opsProxyFactory: string
  } {
    const automateAddress = GELATO_ADDRESSES[this.echainId].automate
    const automateConfig = {
      automate: automateAddress,
      opsProxyFactory: ZeroAddress
    }
    return automateConfig
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
    if (lpConfig == undefined && this.defaultLPConfig != undefined) {
      config = { ...this.defaultLPConfig }
    } else {
      if (lpConfig == undefined) throw new Error('undefined LPConfig')
      config = { ...lpConfig }
    }
    config.automateConfig = this.getAutomateConfig()
    return config
  }

  async deployLP(marketAddress: string, lpConfig?: LPConfig): Promise<DeployResult> {
    console.log(chalk.green(`✨ deploying LP for market: ${marketAddress}`))
    const config = this.getLPConfig(lpConfig)
    const { address: logicAddress } = await this.deploy('ChromaticLPLogic', {
      from: this.deployer,
      args: [config.automateConfig]
    })
    const args = [
      logicAddress,
      config.lpName,
      {
        market: marketAddress,
        ...config.config
      },
      config.feeRates,
      config.distributionRates,
      config.automateConfig
    ]
    const result = await this.deploy('ChromaticLP', {
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
    console.log(
      chalk.green(
        `✨ registered tokens of marketFactory: ${tokens.length}, ${tokens[0].name}, ${tokens[0].address}`
      )
    )
    for (let token of tokens) {
      const markets = await marketFactory.getMarkets(token.address)
      allMarkets.push(...markets)
    }

    return allMarkets
  }

  async getRegistry() {
    const registryDeployed = this.helper.deployed.registryAddress
    if (!registryDeployed) throw new Error('registry not found')
    return this.helper.registry
  }

  async registerLPAll() {
    const registry = await this.getRegistry()

    if (this.hre.network.name !== 'anvil') throw new Error('anvil network only')
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
