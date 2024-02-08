import { DeployTool, retry } from '~/hardhat/common'
import { getDefaultLPConfigs } from '~/hardhat/common/LPConfig'

import chalk from 'chalk'
import { assert } from 'console'
import { formatEther, formatUnits, parseUnits } from 'ethers'
import { task } from 'hardhat/config'
import { HardhatRuntimeEnvironment, TaskArguments } from 'hardhat/types'

task('add-liquidity-market', 'add liquidity to LPs of market')
  .addParam('market', 'The market address')
  .setAction(async (taskArgs: TaskArguments, hre: HardhatRuntimeEnvironment) => {
    const marketAddress = taskArgs.market.toLowerCase()
    const tool = await DeployTool.createAsync(hre, getDefaultLPConfigs())
    const marketAddresses = (await tool.helper.marketAddresses()).map((x) => x.toLowerCase())
    console.log(chalk.green(`marketAddresses: ${JSON.stringify(marketAddresses, null, 2)}`))
    assert(marketAddresses.includes(marketAddress), 'market not found')

    const registry = tool.c.lpRegistry
    const lpAddresses = await registry.lpListByMarket(marketAddress)

    console.log('lpAddresses:', lpAddresses)
    const market = tool.c.market(marketAddress)
    const settlementToken = await retry(market.settlementToken)()
    const token = tool.c.erc20(settlementToken)

    const decimals = await retry(token.decimals)()
    const symbol = await retry(token.symbol)()
    console.log(chalk.green(`settlement token: ${symbol} / decimals ${decimals}`))
    const isBTC = symbol === 'cBTC'

    const lpInfos = await Promise.all(
      lpAddresses.map(async (x) => {
        const lp = tool.c.lp(x)
        return {
          address: x,
          lpTag: await retry(lp.lpTag)(),
          lpName: await retry(lp.lpName)(),
          longShortInfo: await retry(lp.longShortInfo)()
        }
      })
    )

    let i = 0
    for (const config of tool.defaultLPConfigs) {
      // find appropriate lp
      const found = lpInfos.filter((x) => {
        return (
          x.lpTag === config.meta.tag &&
          x.lpName === config.meta.lpName &&
          BigInt(x.longShortInfo) === BigInt(config.meta.longShortInfo!)
        )
      })
      assert(found.length === 1, 'not unique lp found')
      const lpInfo = found[0]

      console.log(`${i++}th lp`, lpInfo)
      const initialLiquidity = isBTC
        ? BigInt(config.initialLiquidity!) / 10n
        : config.initialLiquidity!

      const amount = parseUnits(formatEther(initialLiquidity), decimals)
      console.log(
        chalk.yellow(
          `add liquidity ... \nlp ${lpInfo.address}\namount: ${formatUnits(amount, decimals)}`
        )
      )

      await tool.addLiquidity(lpInfo.address as any, amount)
    }
  })
