import chalk from 'chalk'

import { GELATO_ADDRESSES } from '@gelatonetwork/automate-sdk'
import { ZeroAddress, type Signer } from 'ethers'

import { ChromaticMarketFactory, Client } from '@chromatic-protocol/sdk-ethers-v6'
import { ChromaticLP__factory, type ChromaticLP } from '@chromatic/typechain-types'
import type { DeployOptions, DeployResult } from 'hardhat-deploy/types'
import type { HardhatRuntimeEnvironment } from 'hardhat/types'
import type { LPConfig, LPContractMap, MarketInfo } from './types'

export async function deployLP(
  hre: HardhatRuntimeEnvironment,
  lpConfig: LPConfig
): Promise<LPContractMap> {
  const { config, deployments, getNamedAccounts, ethers, network } = hre
  const { deploy } = deployments
  const { deployer: deployerAddress } = await getNamedAccounts()

  const echainId =
    network.name === 'anvil' ? config.networks.arbitrum_goerli.chainId! : network.config.chainId!

  console.log(chalk.yellow(`✨ Deploying... to ${network.name} ${echainId}`))

  const deployOpts = { from: deployerAddress }

  lpConfig.automateConfig = getAutomateConfig(echainId)
  console.log(chalk.yellow(`✨ automate config : ${JSON.stringify(lpConfig.automateConfig)}`))

  console.log(chalk.yellow(`✨ Deploying... ChromaticLP`))

  const markets = await getMarkets(hre)

  const lpDeployed: LPContractMap = {}
  for (let market of markets) {
    const deployed = await deployMarketLP(deploy, deployOpts, market.address, lpConfig)
    lpDeployed[market.address] = deployed
  }
  return lpDeployed
}

export async function getMarkets(hre: HardhatRuntimeEnvironment): Promise<Array<MarketInfo>> {
  const signers = await hre.ethers.getSigners()

  const client = new Client(hre.network.name, signers[0])
  const marketFactory = client.marketFactory()

  const markets = await getMarketsFromFactory(marketFactory)
  return markets
}

async function deployMarketLP(
  deploy: (name: string, options: DeployOptions) => Promise<DeployResult>,
  deployOpts: DeployOptions,
  marketAddress: string,
  lpConfig: LPConfig
): Promise<{ lpAddress: string; logicAddress: string }> {
  console.log(chalk.yellow(`✨ Deploying... ChromaticLPLogic`))

  // TODO share implementation contract
  const { address: logicAddress } = await deploy('ChromaticLPLogic', {
    ...deployOpts,
    args: [lpConfig.automateConfig]
  })

  const { address: lpAddress } = await deploy('ChromaticLP', {
    ...deployOpts,
    args: [
      logicAddress,
      {
        market: marketAddress,
        ...lpConfig.config
      },
      lpConfig.feeRates,
      lpConfig.distributionRates,
      lpConfig.automateConfig
    ]
  })

  console.log(chalk.green(`✨ marketAdress: ${marketAddress}`))
  console.log(chalk.green(`✨ lpAdress: ${lpAddress}`))
  return {
    lpAddress,
    logicAddress
  }
}

function getAutomateConfig(echainId: any): {
  automate: string
  opsProxyFactory: string
} {
  const automateAddress = GELATO_ADDRESSES[echainId].automate
  const automateConfig = {
    automate: automateAddress,
    opsProxyFactory: ZeroAddress
  }
  return automateConfig
}

async function getMarketsFromFactory(
  marketFactory: ChromaticMarketFactory
): Promise<Array<MarketInfo>> {
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

export function connectChromaticLP(lpAddress: string, signer?: Signer): ChromaticLP {
  return ChromaticLP__factory.connect(lpAddress, signer)
}
