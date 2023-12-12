import { parseEther } from 'ethers'
import { getSqrtDistributionConfig } from './DistributionRates'
import type { LPConfig } from './types'

// prettier-ignore
const FEE_RATES_LONG = [
    1, 2, 3, 4, 5, 6, 7, 8, 9, // 0.01% ~ 0.09%, step 0.01%
    10, 20, 30, 40, 50, 60, 70, 80, 90, // 0.1% ~ 0.9%, step 0.1%
    100, 200, 300, 400, 500, 600, 700, 800, 900, // 1% ~ 9%, step 1%
    1000, 1500, 2000, 2500, 3000, 3500, 4000, 4500, 5000 // 10% ~ 50%, step 5%
];

const FEE_RATES_SHORT = [...FEE_RATES_LONG].reverse().map((x) => -x)
const FEE_RATES_ALL = [...FEE_RATES_SHORT, ...FEE_RATES_LONG]

export function getDefaultLPConfigs(): LPConfig[] {
  const infos = [
    {
      lpName: 'Crescendo',
      tag: 'Low Risk',
      utilizationTargetBPS: 2500,
      startLevel: 0,
      endLevel: 50,
      feeRates: [FEE_RATES_ALL, FEE_RATES_LONG, FEE_RATES_SHORT],
      isLongShorts: [0, 1, -1],
      initialLiquidities: [parseEther('300000'), parseEther('150000'), parseEther('150000')]
    },
    {
      lpName: 'Plateau',
      tag: 'Mid Risk',
      utilizationTargetBPS: 5000,
      startLevel: 50,
      endLevel: 50,
      feeRates: [FEE_RATES_ALL, FEE_RATES_LONG, FEE_RATES_SHORT],
      isLongShorts: [0, 1, -1],
      initialLiquidities: [parseEther('150000'), parseEther('75000'), parseEther('75000')]
    },
    {
      lpName: 'Decresendo',
      tag: 'High Risk',
      utilizationTargetBPS: 7500,
      startLevel: 100,
      endLevel: 50,
      feeRates: [FEE_RATES_ALL, FEE_RATES_LONG, FEE_RATES_SHORT],
      isLongShorts: [0, 1, -1],
      initialLiquidities: [parseEther('100000'), parseEther('50000'), parseEther('50000')]
    }
  ]
  const lpConfigs = []
  for (let info of infos) {
    for (let i = 0; i < info.feeRates.length; i++) {
      const feeRates = info.feeRates[i]
      const distInfo = getSqrtDistributionConfig(
        info.startLevel,
        info.endLevel,
        feeRates.length,
        info.isLongShorts[i]
      )
      const config = {
        meta: {
          lpName: info.lpName,
          tag: info.tag
        },

        config: {
          utilizationTargetBPS: info.utilizationTargetBPS,
          rebalanceBPS: 500,
          rebalanceCheckingInterval: 24 * 60 * 60, // 24 hours
          automationFeeReserved: parseEther('2.0'), // default
          minHoldingValueToRebalance: parseEther('100.0')
        },
        feeRates: feeRates,
        distributionRates: distInfo.distributionRates,
        initialLiquidity: info.initialLiquidities[i]
      }

      lpConfigs.push(config)
    }
  }
  return lpConfigs
}
