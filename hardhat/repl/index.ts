import { extendEnvironment } from 'hardhat/config'
import { lazyFunction } from 'hardhat/plugins'

import chalk from 'chalk'

import { GELATO_ADDRESSES } from '@gelatonetwork/automate-sdk'
import { ZeroAddress } from 'ethers'

import { ChromaticMarketFactory, Client } from '@chromatic-protocol/sdk-ethers-v6'
import type { DeployOptions, DeployResult } from 'hardhat-deploy/types'
import type { HardhatRuntimeEnvironment } from 'hardhat/types'

const LP_CONFIG = {
  config: {
    utilizationTargetBPS: 5000,
    rebalanceBPS: 500,
    rebalnceCheckingInterval: 1 * 60 * 60, // 1 hours
    settleCheckingInterval: 1 * 60 // 1 minutes
  },
  feeRates: [-4, -3, -2, -1, 1, 2, 3, 4],
  distributionRates: [2000, 1500, 1000, 500, 500, 1000, 1500, 2000]
}

extendEnvironment((hre: HardhatRuntimeEnvironment) => {
  hre.deployLP = lazyFunction(() => async () => {
    const { config, deployments, getNamedAccounts, ethers, network } = hre
    const { deploy } = deployments
    const { deployer: deployerAddress } = await getNamedAccounts()

    const signers = await hre.ethers.getSigners()
    const deployer = signers.find((s) => s.address === deployerAddress)!
    const echainId =
      network.name === 'anvil' ? config.networks.arbitrum_goerli.chainId! : network.config.chainId!

    console.log(chalk.yellow(`✨ Deploying... to ${network.name} ${echainId}`))

    const deployOpts = { from: deployerAddress }

    const automateConfig = getAutomateConfig(echainId)
    console.log(chalk.yellow(`✨ automate config : ${JSON.stringify(automateConfig)}`))

    console.log(chalk.yellow(`✨ Deploying... ChromaticLP`))
    const client = new Client(network.name, deployer)
    const marketFactory = client.marketFactory()
    console.log(chalk.green(`✨ client: ${client}}`))

    const markets = await getMarkets(marketFactory)

    for (let market of markets) {
      await deployMarketLP(deploy, deployOpts, market.address, automateConfig)
    }
  })
})

async function deployMarketLP(
  deploy: (name: string, options: DeployOptions) => Promise<DeployResult>,
  deployOpts: DeployOptions,
  marketAddress: string,
  automateConfig: any
) {
  console.log(chalk.yellow(`✨ Deploying... ChromaticLPLogic`))
  const { address: lpLogicAdress } = await deploy('ChromaticLPLogic', {
    ...deployOpts,
    args: [automateConfig]
  })

  const { address: lpAddress } = await deploy('ChromaticLP', {
    ...deployOpts,
    args: [
      lpLogicAdress,
      {
        market: marketAddress,
        ...LP_CONFIG.config
      },
      LP_CONFIG.feeRates,
      LP_CONFIG.distributionRates,
      automateConfig
    ]
  })

  console.log(chalk.green(`✨ marketAdress: ${marketAddress}`))
  console.log(chalk.green(`✨ lpAdress: ${lpAddress}`))
}

function getAutomateConfig(echainId: any) {
  const automateAddress = GELATO_ADDRESSES[echainId].automate
  const automateConfig = {
    automate: automateAddress,
    opsProxyFactory: ZeroAddress
  }
  return automateConfig
}

async function getMarkets(marketFactory: ChromaticMarketFactory) {
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
