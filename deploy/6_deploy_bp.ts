import { parseUnits } from 'ethers'
import type { DeployFunction } from 'hardhat-deploy/types'
import type { HardhatRuntimeEnvironment } from 'hardhat/types'
import { DeployTool } from '~/hardhat/common/DeployTool'
import { BPConfigStruct } from '~/typechain-types/contracts/bp/ChromaticBP'

export function toTimestamp(year: number, month: number, date: number) {
  return BigInt(Date.UTC(year, month - 1, date) / 1000)
}

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const tool = await DeployTool.createAsync(hre)

  const day = BigInt(24 * 3600)
  const week = BigInt(24 * 3600) * 7n
  const minDeposit = parseUnits((250).toString(), 6)

  const bpConfigs: BPConfigStruct[] = [
    {
      lp: '0xfE6e1F50BCebcd58a95E2f136fa4bcBFEbdC74F7', // Crescendo Long & Short
      totalReward: parseUnits((60_000).toString(), 18),
      minRaisingTarget: parseUnits((30_000).toString(), 6),
      maxRaisingTarget: parseUnits((80_000).toString(), 6),
      startTimeOfWarmup: toTimestamp(2024, 2, 28),
      maxDurationOfWarmup: day,
      durationOfLockup: week * 8n,
      minDeposit: minDeposit
    },
    {
      lp: '0xfE6e1F50BCebcd58a95E2f136fa4bcBFEbdC74F7', // Cresendo Long&short
      totalReward: parseUnits((30_000).toString(), 18),
      minRaisingTarget: parseUnits((15_000).toString(), 6),
      maxRaisingTarget: parseUnits((40_000).toString(), 6),
      startTimeOfWarmup: toTimestamp(2024, 2, 29),
      maxDurationOfWarmup: toTimestamp(2024, 3, 2) - toTimestamp(2024, 2, 29),
      durationOfLockup: week * 8n,
      minDeposit: minDeposit
    },
    {
      lp: '0x30ff22B782e6a09B34c2ff3206A8bd2E0D650912', // Plateau Long&Short
      totalReward: parseUnits((30_000).toString(), 18),
      minRaisingTarget: parseUnits((15_000).toString(), 6),
      maxRaisingTarget: parseUnits((40_000).toString(), 6),
      startTimeOfWarmup: toTimestamp(2024, 2, 29),
      maxDurationOfWarmup: toTimestamp(2024, 3, 2) - toTimestamp(2024, 2, 29),
      durationOfLockup: week * 8n,
      minDeposit: minDeposit
    }
  ]
  for (let config of bpConfigs) {
    await tool.deployBP(config)
  }
}

export default func

func.id = 'deploy_bp' // id required to prevent reexecution
func.tags = ['bp']
