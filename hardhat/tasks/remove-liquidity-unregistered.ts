import { AddressType } from '~/hardhat/common/types'

import { Client } from '@chromatic-protocol/liquidity-provider-sdk'
import chalk from 'chalk'
import { task } from 'hardhat/config'
import { HardhatRuntimeEnvironment, TaskArguments } from 'hardhat/types'
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
  .setAction(async (taskArgs: TaskArguments, hre: HardhatRuntimeEnvironment) => {
    const infos = await listRemovableLiquidityExist(hre, taskArgs.address)
    if (infos.length == 0) {
      console.log(chalk.yellow(`removable liquidity not found from registry ${taskArgs.address})`))
      return
    }
    const client = await getSDKClient(hre)
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
