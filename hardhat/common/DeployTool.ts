import chalk from 'chalk'
import type { HardhatRuntimeEnvironment } from 'hardhat/types'
const prompt = require('prompt-sync')({ sigint: true })

import { DeployOptions, DeployResult } from 'hardhat-deploy/types'
import { DEPLOYED } from '~/hardhat/common/DeployedStore'
import { Helper } from '~/hardhat/common/Helper'
import { ChromaticLPRegistry, ChromaticLP__factory } from '~/typechain-types'

import { formatEther, parseUnits } from 'ethers'
import { getDefaultLPConfigs } from '~/hardhat/common/LPConfig'
import { BPConfigStruct } from '~/typechain-types/contracts/bp/ChromaticBP'
import { getAutomateAddress } from './getAutomateConfig'
import type {
  AddressType,
  AutomateConfig,
  LPConfig,
  LPDeployedResultMap,
  MarketInfo
} from './types'

export type * from './types'

function sleep(ms: number) {
  return new Promise((r) => setTimeout(r, ms))
}

export function retry(f: any, maxRetry = 10) {
  async function _retry(...args: any[]) {
    let waitInterval = 1000
    await sleep(100)
    for (let i = 0; i < maxRetry; i++) {
      try {
        return f(...args)
      } catch {
        await sleep(waitInterval)
        waitInterval *= 2
        continue
      }
    }
  }
  return _retry
}

function adjustGasLimit(f: any) {
  const MIN_GAS_LIMIT_SETTLE_ALL = 10n ** 7n
  async function _moreGasLimit(...args: any[]) {
    const gas = await f.estimateGas(...args)

    return await f(...args, {
      gasLimit: MIN_GAS_LIMIT_SETTLE_ALL >= gas ? MIN_GAS_LIMIT_SETTLE_ALL : gas
    })
  }
  return _moreGasLimit
}

console.assert = function (cond, text) {
  if (cond) return
  throw new Error(text || 'Assertion failed!')
}
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
  get c() {
    return this.helper.c
  }
  get deployer() {
    return this.helper.signerAddress
  }
  get signer() {
    return this.helper.signer
  }

  private get _deploy() {
    return retry(this.hre.deployments.deploy)
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
    await this.deployAutomateBP()
    await this.deployBPFactory()
  }

  async deployRegistry(): Promise<DeployResult> {
    const factory = this.c.marketFactory
    const factoryAddress = await factory.getAddress()
    console.log(`factoryAddress: ${factoryAddress}`)

    const res = await this.deploy('ChromaticLPRegistry', {
      from: this.deployer,
      args: [factoryAddress]
    })

    DEPLOYED.saveRegistry(res.address as AddressType)
    if (res.newlyDeployed)
      await this.verify({ address: res.address, constructorArguments: [factoryAddress] })

    return res
  }

  async deployBPFactory(): Promise<DeployResult> {
    console.log(chalk.cyan(`deploying ChromaticBPFactory:`))
    if (!DEPLOYED.automateBP) {
      throw new Error('deploy AutomateBP first')
    }
    const factory = this.c.marketFactory
    const factoryAddress = await factory.getAddress()

    const args = [factoryAddress, DEPLOYED.automateBP]
    const res = await this.deploy('ChromaticBPFactory', {
      from: this.deployer,
      args: args
    })
    DEPLOYED.saveBPFactory(res.address as AddressType)

    if (res.newlyDeployed) await this.verify({ address: res.address, constructorArguments: args })

    return res
  }

  async deployBP(bpConfig: BPConfigStruct) {
    console.log(chalk.cyan(`deploying BP:`), bpConfig)
    const factory = await this.c.bpFactory
    const blockFrom = await this.hre.ethers.provider.getBlockNumber()
    const tx = await retry(factory.createBP)(bpConfig)
    await tx.wait()
    const filter = factory.filters.ChromaticBPCreated(bpConfig.lp)
    const logs = await factory.queryFilter(filter, blockFrom, 'latest')
    const bpAddress = logs[logs.length - 1].args[1]
    console.log(chalk.cyan(`ChromaticBPCreated(lp: ${logs[0].args[0]}, bp:${bpAddress})`))

    await this.verify({
      address: bpAddress,
      constructorArguments: [bpConfig, this.helper.deployed.bpFactory]
    })
  }

  get automateConfig(): AutomateConfig {
    return getAutomateAddress(this.hre)
  }

  async getLPDeployConfigs(lpConfigs?: LPConfig[]) {
    const markets = await this.helper.markets()
    lpConfigs = lpConfigs == undefined ? this.defaultLPConfigs : lpConfigs

    const deployConfigs = []

    for (let market of markets) {
      for (let lpConfig of lpConfigs) {
        const config = this.adjustLPConfig(market, lpConfig)
        deployConfigs.push({
          market: market,
          config: config
        })
      }
    }
    return deployConfigs
  }

  async addInitialLiquidityAll(dryrun = false) {
    // helper to run addLiquidity to already deployed
    const deployConfigs = await this.getLPDeployConfigs()
    const lpAddresses = this.helper.lpAddresses.map((x) => x.toLowerCase())

    console.assert(
      lpAddresses.length === deployConfigs.length,
      chalk.red('not same length lpAddress and deployConfigs')
    )

    let i = 0
    for (let { market, config } of deployConfigs) {
      const lp = lpAddresses[i++] as AddressType
      const lpOfMarket = this.helper.deployed.lpOfMarket(market.address).map((x) => x.toLowerCase())
      console.assert(
        lpOfMarket.includes(lp),
        chalk.red(`lp ${lp} not found in the following deployed LPs for market ${market}: \n 
          ${JSON.stringify(lpOfMarket, null, 2)}`)
      )

      try {
        console.log(
          chalk.cyan(
            `add initial liquidity: [${market.address}] 
            lp:[${lp}]
            ${formatEther(config.initialLiquidity || 0)}`
          )
        )
        if (!dryrun) {
          const input = prompt('proceed? (y/n)', 'y')
          if (input?.toLowerCase() === 'n') {
            console.log('skipped')
            continue
          }
        }
        if (config.initialLiquidity) {
          if (!dryrun) await this.addLiquidity(lp as AddressType, BigInt(config.initialLiquidity))
        }
      } catch (e) {
        console.log(chalk.redBright('failed to add liquidity initially'))
        console.log(e)
      }
    }
  }

  async deployLPsOfSettlementToken(
    settlementToken: AddressType,
    lpConfigs?: LPConfig[]
  ): Promise<LPDeployedResultMap> {
    const markets = await this.helper.marketsOfSettlementToken(settlementToken)
    lpConfigs = lpConfigs == undefined ? this.defaultLPConfigs : lpConfigs
    const lpDeployed: LPDeployedResultMap = {}

    let i = 0
    for (let market of markets) {
      console.log(`\n${i++}th market [${market.address}]`)
      const deployedResults = await this.deployLPs(market, lpConfigs)

      lpDeployed[market.address] = deployedResults
    }
    return lpDeployed
  }

  async deployLPs(market: MarketInfo, lpConfigs?: LPConfig[]): Promise<DeployResult[]> {
    const deployedResults = []
    let i = 0

    lpConfigs = lpConfigs == undefined ? this.defaultLPConfigs : lpConfigs
    for (let lpConfig of lpConfigs) {
      const config = this.adjustLPConfig(market, lpConfig)
      console.log(`\n\n${i++}th LP`)
      try {
        const deployed = await this.deployLP(market.address, config, false, market)
        deployedResults.push(deployed)
      } catch (e) {
        console.log(`skipped`, e)
        continue
      }
    }

    return deployedResults
  }

  async deployAllLP(lpConfigs?: LPConfig[]): Promise<LPDeployedResultMap> {
    const markets = await this.helper.markets()
    lpConfigs = lpConfigs == undefined ? this.defaultLPConfigs : lpConfigs
    const lpDeployed: LPDeployedResultMap = {}

    let i = 0
    for (let market of markets) {
      console.log(`\n${i++}th market [${market.address}]`)
      const deployedResults = await this.deployLPs(market, lpConfigs)

      lpDeployed[market.address] = deployedResults
    }
    return lpDeployed
  }

  adjustLPConfig(marketInfo: MarketInfo, lpConfig: LPConfig): LPConfig {
    const iscBTC = marketInfo.settlementToken.symbol === 'cBTC'
    const iscUSDT = marketInfo.settlementToken.symbol === 'cUSDT'
    const decimals = marketInfo.settlementToken.decimals
    console.log('is cBTC?: ', iscBTC)

    const automationFeeReserved = parseUnits(
      formatEther(lpConfig.config.automationFeeReserved),
      decimals
    )
    const minHoldingValueToRebalance = parseUnits(
      formatEther(lpConfig.config.minHoldingValueToRebalance),
      decimals
    )
    const initialLiquidity = parseUnits(formatEther(lpConfig.initialLiquidity!), decimals)

    let config = {
      ...lpConfig,
      config: {
        ...lpConfig.config,
        automationFeeReserved: iscBTC ? automationFeeReserved / 10n : automationFeeReserved,
        minHoldingValueToRebalance: iscBTC
          ? minHoldingValueToRebalance / 10n
          : minHoldingValueToRebalance
      },
      automateConfig: DEPLOYED.automateLP || this.helper.deployed.automateLP,
      initialLiquidity:
        iscBTC && lpConfig.initialLiquidity ? initialLiquidity / 10n : initialLiquidity
    }
    return config
  }

  async deployAutomateLP(): Promise<DeployResult> {
    console.log(chalk.green(`✨ deploying AutomateLP`))
    const args = [getAutomateAddress(this.hre)]
    const FQN = this.hre.network.tags.mate2
      ? 'contracts/automation/mate2/AutomateLP.sol:AutomateLP'
      : 'contracts/automation/gelato/AutomateLP.sol:AutomateLP'

    const res = await this.deploy('AutomateLP', {
      contract: FQN,
      from: this.deployer,
      args: args
    })
    if (res.newlyDeployed) await this.verify({ address: res.address, constructorArguments: args })
    DEPLOYED.saveAutomateLP(res.address as AddressType)

    if (this.hre.network.tags.mate2 && res.newlyDeployed) {
      await this.addWhitelistedRegistrar(res.address)
    }

    // addwhitelist

    return res
  }

  async deployAutomateBP(): Promise<DeployResult> {
    console.log(chalk.green(`✨ deploying AutomateBP`))
    const args = [getAutomateAddress(this.hre)]
    const FQN = this.hre.network.tags.mate2
      ? 'contracts/automation/mate2/AutomateBP.sol:AutomateBP'
      : 'contracts/automation/gelato/AutomateBP.sol:AutomateBP'

    const res = await this.deploy('AutomateBP', {
      contract: FQN,
      from: this.deployer,
      args: args
    })
    if (res.newlyDeployed) await this.verify({ address: res.address, constructorArguments: args })
    DEPLOYED.saveAutomateBP(res.address as AddressType)

    if (this.hre.network.tags.mate2 && res.newlyDeployed) {
      await this.addWhitelistedRegistrar(res.address)
    }

    return res
  }

  async deployLP(
    marketAddress: string,
    lpConfig: LPConfig,
    adjust = true,
    marketInfo: MarketInfo | undefined = undefined
  ): Promise<DeployResult> {
    console.log(chalk.green(`✨ deploying LP for market: ${marketAddress}`))
    let config = lpConfig
    if (!marketInfo) {
      marketInfo = (await this.helper.markets()).find(
        (x) => x.address == marketAddress
      ) as MarketInfo
    }
    if (adjust) {
      config = this.adjustLPConfig(marketInfo, lpConfig)
    }

    if (!config.automateConfig) throw new Error('AutomateLP not found')
    if (!config.meta?.lpName) throw new Error('lpName not found')
    if (!config.meta?.tag) throw new Error('lp-tag not found')

    const { address: logicAddress } = await this.deploy('ChromaticLPLogic', {
      from: this.deployer,
      args: []
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
    await (await retry(lpContract.createRebalanceTask)()).wait()

    if (config.initialLiquidity) {
      try {
        console.log(chalk.cyan(`add initial liquidity: ${formatEther(config.initialLiquidity)}`))
        await this.addLiquidity(result.address as AddressType, BigInt(config.initialLiquidity))
      } catch {
        console.log(chalk.redBright('failed to add liquidity initially'))
      }
    }

    return result
  }

  async addLiquidity(lpAddress: AddressType, amount: bigint) {
    const lp = this.c.lp(lpAddress)
    const tokenAddress = await retry(lp.settlementToken)()
    const token = this.c.erc20(tokenAddress)
    const balance = await retry(token.balanceOf)(this.deployer)

    console.log(` - settlementTokenBalance: ${balance}`)
    if (amount > balance) {
      // mint seperately
      throw new Error('not enough token to add liquidity')
    } else {
      console.log('enough balance')
    }

    await (await retry(token.approve)(lpAddress, amount)).wait()

    const tx = await retry(adjustGasLimit(lp.addLiquidity))(amount, this.deployer)
    await tx.wait()
  }

  async removeAllLiquidity() {
    for (const lpAddress of this.helper.lpAddresses) {
      await this.removeLiquidityAll(lpAddress as AddressType)
    }
  }

  async removeLiquidity(lpAddress: AddressType, amount: bigint) {
    const lp = this.c.lp(lpAddress)
    // const tokenAddress = await lp.lpToken()
    const token = this.c.erc20(lpAddress) // lp token
    const lpTokenBalance = await retry(token.balanceOf)(this.deployer)
    await (await retry(token.approve)(lpAddress, amount)).wait()

    console.log(`  - lpTokenBalance: ${lpTokenBalance}`)
    const tx = await retry(adjustGasLimit(lp.removeLiquidity))(amount, this.deployer)
    await tx.wait()
  }

  async removeLiquidityAll(lpAddress: AddressType) {
    const lp = this.c.lp(lpAddress)
    const token = this.c.erc20(lpAddress) // lp token
    const lpTokenBalance = await retry(token.balanceOf)(this.deployer)
    await (await retry(token.approve)(lpAddress, lpTokenBalance)).wait()

    console.log(`  - lpTokenBalance: ${lpTokenBalance}`)
    const tx = await retry(lp.removeLiquidity)(lpTokenBalance, this.deployer)
    await tx.wait()
  }

  async registerAllLP() {
    let registry = this.c.lpRegistry

    if (!this.hre.network.name.startsWith('anvil')) throw new Error('local network only')
    for (const lpAddress of this.helper.lpAddresses) {
      await this.registerLP(lpAddress, registry)
    }
  }

  async unregisterAllLP() {
    let registry = this.c.lpRegistry

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
    if (!registry) registry = this.c.lpRegistry

    console.log(chalk.green(`✨ registering lpAddress to registry: ${lpAddress}`))
    await (await retry(registry.register)(lpAddress)).wait()
  }

  async unregisterLP(lpAddress: string, registry?: ChromaticLPRegistry) {
    if (!registry) registry = this.c.lpRegistry
    console.log(chalk.green(`✨ uregistering lpAddress from registry: ${lpAddress}`))
    await (await retry(registry.unregister)(lpAddress)).wait()
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
    const lp = this.c.lp(lpAddress)
    console.log(chalk.yellow(`🔧 createRebalanceTask...: ${lpAddress}`))
    await (await retry(lp.createRebalanceTask)()).wait()
  }

  async cancelRebalanceTask(lpAddress: string) {
    const lp = this.c.lp(lpAddress)
    console.log(chalk.yellow(`🔧 cancelRebalanceTask...: ${lpAddress}`))
    await (await retry(lp.cancelRebalanceTask)()).wait()
  }

  async addWhitelistedRegistrar(automate: string) {
    console.assert(this.hre.network.tags.mate2, 'not mate2')

    const mate2Registry = this.c.mate2Registry(getAutomateAddress(this.hre))
    console.log(chalk.yellow(`🔧 addWhitelistedRegistrar...: ${automate}`))
    await (await retry(mate2Registry.addWhitelistedRegistrar)(automate)).wait()
  }
  async removeWhitelistedRegistrar(automate: string) {
    console.assert(this.hre.network.tags.mate2, 'not mate2')

    const mate2Registry = this.c.mate2Registry(getAutomateAddress(this.hre))
    console.log(chalk.yellow(`🔧 removeWhitelistedRegistrar...: ${automate}`))
    await (await retry(mate2Registry.removeWhitelistedRegistrar)(automate)).wait()
  }
}
