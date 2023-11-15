import { parseEther } from 'ethers'
import { getLinearDistributionConfig } from './DistributionRates'
import type { LPConfig } from './types'

// prettier-ignore
const _FEE_RATES = [
    1, 2, 3, 4, 5, 6, 7, 8, 9, // 0.01% ~ 0.09%, step 0.01%
    10, 20, 30, 40, 50, 60, 70, 80, 90, // 0.1% ~ 0.9%, step 0.1%
    100, 200, 300, 400, 500, 600, 700, 800, 900, // 1% ~ 9%, step 1%
    1000, 1500, 2000, 2500, 3000, 3500, 4000, 4500, 5000 // 10% ~ 50%, step 5%
];

const FEE_RATES = [...[..._FEE_RATES].reverse().map((x) => -x), ..._FEE_RATES]

export function getDefaultDistribution(feeRates: number[]): number[] {
  const sum = feeRates.reduce((s, x) => s + Math.abs(x), 0) // 63990

  const BPS = 10000n
  const MIN_RATE = 10n

  let distributionRates = feeRates.map((x) => {
    let r = (BigInt(Math.abs(x)) * BPS) / BigInt(sum)
    return r < MIN_RATE ? Number(MIN_RATE) : Number(r)
  })
  return distributionRates
}

export function getDefaultLPConfigs(): LPConfig[] {
  const infos = [
    {
      lpName: 'Crescendo',
      tag: 'Low Risk',
      utilizationTargetBPS: 2500,
      startLevel: 0,
      endLevel: 50,
      initialLiquidity: parseEther('30000')
    },
    {
      lpName: 'Plateau',
      tag: 'Mid Risk',
      utilizationTargetBPS: 5000,
      startLevel: 50,
      endLevel: 50,
      initialLiquidity: parseEther('15000')
    },
    {
      lpName: 'Decresendo',
      tag: 'High Risk',
      utilizationTargetBPS: 7500,
      startLevel: 100,
      endLevel: 50,
      initialLiquidity: parseEther('10000')
    }
  ]
  const lpConfigs = []
  for (let info of infos) {
    const distInfo = getLinearDistributionConfig(info.startLevel, info.endLevel, _FEE_RATES.length)
    // console.log('linear distribution information:', distInfo)
    console.assert(
      distInfo.utilizationTargetBPS == info.utilizationTargetBPS,
      'check utilization target is correct'
    )
    const config = {
      meta: {
        lpName: info.lpName,
        tag: info.tag
      },

      config: {
        utilizationTargetBPS: distInfo.utilizationTargetBPS,
        rebalanceBPS: 500,
        rebalanceCheckingInterval: 24 * 60 * 60, // 24 hours
        settleCheckingInterval: 1 * 60, // 1 minutes
        automationFeeReserved: parseEther('2.0'), // default
        minHoldingValueToRebalance: parseEther('100.0')
      },
      feeRates: FEE_RATES,
      distributionRates: distInfo.distributionRates,
      initialLiquidity: info.initialLiquidity
    }

    lpConfigs.push(config)
  }
  return lpConfigs
}
