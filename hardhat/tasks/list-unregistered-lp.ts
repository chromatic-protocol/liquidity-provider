import { AddressType } from '~/hardhat/common/types'

import chalk from 'chalk'
import { task } from 'hardhat/config'
import { HardhatRuntimeEnvironment, TaskArguments } from 'hardhat/types'
import type { WalletClient } from 'viem'
import { createWalletClient, http, parseAbiItem } from 'viem'
import { privateKeyToAccount } from 'viem/accounts'
import { getSDKClient } from '~/hardhat/common'

export async function getWalletClientFromKey(
  hre: HardhatRuntimeEnvironment,
  key: string
): Promise<WalletClient> {
  let publicClient = await hre.viem.getPublicClient()
  const walletClient = createWalletClient({
    account: privateKeyToAccount(key as any),
    chain: publicClient.chain,
    transport: http()
  })

  return walletClient
}

export async function listUnregisterEvent(
  hre: HardhatRuntimeEnvironment,
  registryAddress: AddressType
) {
  const publicClient = await hre.viem.getPublicClient()

  const logs = await publicClient.getLogs({
    address: registryAddress,
    event: parseAbiItem(
      'event ChromaticLPUnregistered(address indexed market, address indexed lp)'
    ),
    fromBlock: 'earliest',
    toBlock: 'latest'
  })
  return logs.map((x) => x.args)
}

export async function listRemovableLiquidityExist(
  hre: HardhatRuntimeEnvironment,
  registryAddress: AddressType,
  walletClient?: WalletClient
) {
  const events = await listUnregisterEvent(hre, registryAddress)

  const client = await getSDKClient(hre, walletClient)
  const address = client.walletClient!.account!.address

  const removableInfo = []
  for (let event of events) {
    const amount = await client.lp().balanceOf(event.lp as any, address)
    if (amount > 0n) {
      console.log(`removable amount: ${amount} from ${event.lp}`)
      removableInfo.push({ ...event, amount })
    }
  }
  return removableInfo
}

task('list-unregistered-lp', 'List unregistered lp addresses from given registry')
  .addParam('address', 'The registry address')
  .setAction(async (taskArgs: TaskArguments, hre: HardhatRuntimeEnvironment) => {
    const logs = await listUnregisterEvent(hre, taskArgs.address)
    console.log(`unregistered lp address in registry(${taskArgs.address})`)
    console.log('logs:', logs)
  })

task(
  'list-removable-lp',
  'List lp addresses that has removable liquidity exist from given registry'
)
  .addParam('address', 'The registry address')
  .addOptionalParam('private', 'The private key of wallet account')
  .setAction(async (taskArgs: TaskArguments, hre: HardhatRuntimeEnvironment) => {
    let walletClient

    if (taskArgs.private) {
      walletClient = await getWalletClientFromKey(hre, taskArgs.private)
    }

    const infos = await listRemovableLiquidityExist(hre, taskArgs.address, walletClient)
    if (infos.length == 0) {
      console.log(chalk.yellow(`removable liquidity not found from registry ${taskArgs.address})`))
      return
    }
    console.log(chalk.yellow(`removable liquidity found from from registry ${taskArgs.address}`))
    console.log(infos)
  })
