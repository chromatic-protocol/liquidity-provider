import { AddressType } from '~/hardhat/common/types'

import { Client } from '@chromatic-protocol/liquidity-provider-sdk'
import chalk from 'chalk'
import { task } from 'hardhat/config'
import { HardhatRuntimeEnvironment, TaskArguments } from 'hardhat/types'
import { privateKeyToAccount } from 'viem/accounts'
import { getSDKClient } from '~/hardhat/common'
import { listRemovableLiquidityExist } from './list-unregistered-lp'

export async function removeLiquidity(
  hre: HardhatRuntimeEnvironment,
  lpAddress: AddressType,
  amount: bigint,
  client?: Client
) {
  if (!client) client = await getSDKClient(hre)

  await client.lp().removeLiquidity(lpAddress, amount)
}

task('remove-liquidity-unregistered', 'remove liquidity from all lp unregistered from the registry')
  .addParam('address', 'The registry address')
  .addOptionalParam('private', 'private key of wallet account')
  .setAction(async (taskArgs: TaskArguments, hre: HardhatRuntimeEnvironment) => {
    let walletClient
    if (taskArgs.private) {
      ;[walletClient] = await hre.viem.getWalletClients({
        account: privateKeyToAccount(taskArgs.private as any)
      })
    }

    const infos = await listRemovableLiquidityExist(hre, taskArgs.address, walletClient)
    if (infos.length == 0) {
      console.log(chalk.yellow(`removable liquidity not found from registry ${taskArgs.address})`))
      return
    }
    const client = await getSDKClient(hre, walletClient)
    const walletAddress = client.walletClient!.account!.address
    console.log(`remove liquidity from unregistered LPs`)
    console.log(` - registryAddress : ${taskArgs.address}`)
    console.log(` - walletAddress : ${walletAddress}`)

    for (let info of infos) {
      console.log(` - lpAddress : ${info.lp}`)
      console.log(` - marketAddress : ${info.market}`)
      console.log(` - lpTokenAmount : ${info.amount}`)

      await removeLiquidity(hre, info.lp as AddressType, info.amount, client)
    }
  })
