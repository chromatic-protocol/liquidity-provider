import { GELATO_ADDRESSES } from '@gelatonetwork/automate-sdk'
import chalk from 'chalk'
import { ZeroAddress } from 'ethers'
import type { HardhatRuntimeEnvironment } from 'hardhat/types'

import { Client as ClientSDK } from '@chromatic-protocol/sdk-ethers-v6'
import { Signer } from 'ethers'
import { DeployOptions, DeployResult } from 'hardhat-deploy/types'
import type { LPConfig, MarketInfo } from './types'
export type * from './types'

export class DeployTool {
  private client: ClientSDK | undefined
  private deployer: string
  public signer: Signer | undefined

  constructor(
    public readonly hre: HardhatRuntimeEnvironment,
    public readonly defaultLPConfig?: LPConfig
  ) {
    this.client = undefined
    this.signer = undefined
    this.deployer = ''
  }
  async initialize() {
    const { deployer: deployerAddress } = await this.hre.getNamedAccounts()
    const signers = await this.hre.ethers.getSigners()
    this.signer = signers.find((s) => s.address === deployerAddress)!
    this.deployer = deployerAddress
    this.client = new ClientSDK(this.hre.network.name, this.signer)
  }
  static async createAsync(hre: HardhatRuntimeEnvironment, defaultLPConfig?: LPConfig) {
    const tool = new DeployTool(hre, defaultLPConfig)
    await tool.initialize()
    return tool
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
    const factory = this.client!.marketFactory().contracts().marketFactory
    const factoryAddress = await factory.getAddress()

    return await this.deploy('ChromaticLPRegistry', {
      from: this.deployer,
      args: [factoryAddress]
    })
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

    // FIXME: type and store result
    const lpDeployed: any = {}
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

    return await this.deploy('ChromaticLP', {
      from: this.deployer,
      args: [
        logicAddress,
        {
          market: marketAddress,
          ...config.config
        },
        config.feeRates,
        config.distributionRates,
        config.automateConfig
      ]
    })
  }

  async getMarkets(): Promise<MarketInfo[]> {
    const marketFactory = this.client!.marketFactory()

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

  async getLPRegistryDeployed() {
    return await this.hre.deployments.get('ChromaticLPRegistry')
  }
}
