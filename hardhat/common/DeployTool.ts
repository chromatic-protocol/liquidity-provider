import chalk from 'chalk'
import type { HardhatRuntimeEnvironment } from 'hardhat/types'
const prompt = require('prompt-sync')({ sigint: true })

import { DeployOptions, DeployResult } from 'hardhat-deploy/types'
import { DEPLOYED } from '~/hardhat/common/DeployedStore'
import { Helper } from '~/hardhat/common/Helper'
import { ChromaticLPRegistry, ChromaticLP__factory } from '~/typechain-types'

import { formatEther } from 'ethers'
import { getSDKClient } from '~/hardhat/common/Client'
import { getDefaultLPConfigs } from '~/hardhat/common/LPConfig'
import { BPConfigStruct } from '~/typechain-types/contracts/bp/ChromaticBP'
import { getAutomateAddress, getAutomateConfig } from './getAutomateConfig'
import type {
  AddressType,
  AutomateConfig,
  LPConfig,
  LPDeployedResultMap,
  MarketInfo
} from './types'

export type * from './types'
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

    await this.deployAutomateLP()

    const result = await this.deployAllLP(this.defaultLPConfigs)
    for (let deployed of [].concat(...Object.values(result))) {
      await this.registerLP(deployed['address'])
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

    DEPLOYED.saveRegistry(res.address as AddressType)
    await this.verify({ address: res.address, constructorArguments: [factoryAddress] })

    return res
  }

  async deployBPFactory(): Promise<DeployResult> {
    console.log(chalk.cyan(`deploying ChromaticBPFactory:`))
    if (!DEPLOYED.automateBP) {
      throw new Error('deploy AutomateBP first')
    }

    const res = await this.deploy('ChromaticBPFactory', {
      from: this.deployer,
      args: [DEPLOYED.automateBP]
    })
    DEPLOYED.saveBPFactory(res.address as AddressType)

    await this.verify({ address: res.address, constructorArguments: [] })

    return res
  }

  async deployBP(bpConfig: BPConfigStruct) {
    console.log(chalk.cyan(`deploying BP:`), bpConfig)
    const factory = await this.getBPFactory()
    const tx = await factory.createBP(bpConfig)
    await tx.wait()
    const filter = factory.filters.ChromaticBPCreated(bpConfig.lp)
    const logs = await factory.queryFilter(filter)
    const bpAddress = logs[0].args[1]
    console.log(chalk.cyan(`ChromaticBPCreated(lp: ${logs[0].args[0]}, bp:${bpAddress})`))

    await this.verify({ address: bpAddress, constructorArguments: [bpConfig, this.automateConfig] })
  }

  get automateConfig(): AutomateConfig {
    return getAutomateConfig(this.hre)
  }

  async deployAllLP(lpConfigs?: LPConfig[]): Promise<LPDeployedResultMap> {
    const markets = await this.getMarkets()
    lpConfigs = lpConfigs == undefined ? this.defaultLPConfigs : lpConfigs
    const lpDeployed: LPDeployedResultMap = {}

    let i = 0
    for (let market of markets) {
      const deployedResults = []
      for (let lpConfig of lpConfigs) {
        const config = this.adjustLPConfig(market, lpConfig)
        console.log(`\n\n${i++}th LP`)
        try {
          const deployed = await this.deployLP(market.address, config, false)
          deployedResults.push(deployed)
        } catch {
          console.log(`skipped`)
          continue
        }
      }

      lpDeployed[market.address] = deployedResults
    }
    return lpDeployed
  }

  adjustLPConfig(marketInfo: MarketInfo, lpConfig: LPConfig): LPConfig {
    const iscBTC = marketInfo.settlementToken.name == 'cBTC'
    console.log('is cBTC?: ', iscBTC)

    let config = {
      ...lpConfig,
      config: {
        ...lpConfig.config,
        automationFeeReserved: iscBTC
          ? BigInt(lpConfig.config.automationFeeReserved) / 10n
          : BigInt(lpConfig.config.automationFeeReserved)
      },
      automateConfig: DEPLOYED.automateLP,
      initialLiquidity:
        iscBTC && lpConfig.initialLiquidity
          ? BigInt(lpConfig.initialLiquidity) / 10n
          : lpConfig.initialLiquidity
    }
    return config
  }

  async deployAutomateLP(): Promise<DeployResult> {
    console.log(chalk.green(`✨ deploying AutomateLP`))
    const args = [getAutomateAddress(this.hre)]
    const result = await this.deploy('AutomateLP', {
      from: this.deployer,
      args: args
    })
    await this.verify({ address: result.address, constructorArguments: args })
    DEPLOYED.saveAutomateLP(result.address as AddressType)

    return result
  }

  async deployAutomateBP(): Promise<DeployResult> {
    console.log(chalk.green(`✨ deploying AutomateBP`))
    const args = [getAutomateAddress(this.hre)]
    const result = await this.deploy('AutomateBP', {
      from: this.deployer,
      args: args
    })
    await this.verify({ address: result.address, constructorArguments: args })
    DEPLOYED.saveAutomateBP(result.address as AddressType)

    return result
  }

  async deployLP(marketAddress: string, lpConfig: LPConfig, adjust = true): Promise<DeployResult> {
    console.log(chalk.green(`✨ deploying LP for market: ${marketAddress}`))
    let config = lpConfig
    if (adjust) {
      const marketInfo: MarketInfo = (await this.getMarkets()).find(
        (x) => x.address == marketAddress
      ) as MarketInfo

      config = this.adjustLPConfig(marketInfo, lpConfig)
    }

    if (!config.automateConfig) throw new Error('AutomateLP not found')
    if (!config.meta?.lpName) throw new Error('lpName not found')
    if (!config.meta?.tag) throw new Error('lp-tag not found')

    const { address: logicAddress } = await this.deploy('ChromaticLPLogic', {
      from: this.deployer,
      args: [config.automateConfig]
    })
    if (config.feeRates.length != config.distributionRates.length) {
      console.log('feeRates:\n', chalk.red(JSON.stringify(config.feeRates, null)))
      console.log('distributionRates:\n', chalk.red(JSON.stringify(config.distributionRates, null)))
      throw new Error(
        `check feeRates and distributionRates pair, ${config.feeRates.length}, ${config.distributionRates.length}`
      )
    }
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

    const input = prompt('proceed? (y/n)', 'y')
    if (input?.toLowerCase() === 'n') {
      throw new Error('user rejected')
    }

    const result = await this.deploy('ChromaticLP', {
      from: this.deployer,
      args: args
    })
    await this.verify({ address: result.address, constructorArguments: args })

    DEPLOYED.saveLP(result.address as AddressType, marketAddress as AddressType)

    const lpContract = ChromaticLP__factory.connect(result.address, this.signer)

    console.log(chalk.cyan(`createRebalanceTask`))
    await (await lpContract.createRebalanceTask()).wait()

    if (config.initialLiquidity) {
      try {
        console.log(chalk.cyan(`add initial liqduitity: ${formatEther(config.initialLiquidity)}`))
        await this.addLiquidity(result.address as AddressType, BigInt(config.initialLiquidity))
      } catch {
        console.log(chalk.redBright('failed to add liquidity initially'))
      }
    }

    return result
  }

  async addLiquidity(lpAddress: AddressType, amount: bigint) {
    const client = await getSDKClient(this.hre)
    const address = client.walletClient!.account!.address
    let token = await client.lp().contracts().settlementToken(lpAddress)
    const settlementTokenBalance = await token.read.balanceOf([address])
    console.log(`  - settlementTokenBalance: ${settlementTokenBalance}`)
    if (amount > settlementTokenBalance) {
      // mint seperately
      throw new Error('not enough token to add liquidity')
    }

    await client.lp().addLiquidity(lpAddress, amount)
  }

  async removeLiquidity(lpAddress: AddressType, amount: bigint) {
    const client = await getSDKClient(this.hre)
    const address = client.walletClient!.account!.address
    let lpTokenBalance = await client.lp().balanceOf(lpAddress, address)

    console.log(`  - lpTokenBalance: ${lpTokenBalance}`)
    await client.lp().removeLiquidity(lpAddress, amount)
  }

  async removeLiquidityAll(lpAddress: AddressType) {
    const client = await getSDKClient(this.hre)
    const address = client.walletClient!.account!.address
    let lpTokenBalance = await client.lp().balanceOf(lpAddress, address)

    console.log(`  - lpTokenBalance: ${lpTokenBalance}`)
    await client.lp().removeLiquidity(lpAddress, lpTokenBalance)
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
      allMarkets.push(
        ...markets.map((x) => {
          return { ...x, settlementToken: token }
        })
      )
    }

    return allMarkets as MarketInfo[]
  }

  async getRegistry() {
    const registryDeployed = this.helper.deployed.registryAddress
    if (!registryDeployed) throw new Error('registry not found')
    return this.helper.registry
  }

  async getBPFactory() {
    return this.helper.bpFactory
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
    if (!this.hre.network.tags.local) {
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
}
