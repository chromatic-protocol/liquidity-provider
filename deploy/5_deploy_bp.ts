import { parseUnits } from 'ethers'
import type { DeployFunction } from 'hardhat-deploy/types'
import type { HardhatRuntimeEnvironment } from 'hardhat/types'
import { DeployTool } from '~/hardhat/common/DeployTool'
import { BPConfigStruct } from '~/typechain-types/contracts/bp/ChromaticBP'

export function toTimestamp(date: Date) {
  return BigInt(Math.floor(date.getTime() / 1000))
}

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const tool = await DeployTool.createAsync(hre)

  const week = BigInt(24 * 3600) * 7n

  const startTimeOfWarmup = 1708473600 // 2024.02.21 UTC 00:00 (1708473600)
  const maxDurationOfWarmup = week

  const bpConfigs: BPConfigStruct[] = [
    {
      lp: '0xAD6FE0A0d746aEEEDEeAb19AdBaDBE58249cD0c7',
      totalReward: parseUnits((100_000).toString(), 18),
      minRaisingTarget: parseUnits((100_000).toString(), 6),
      maxRaisingTarget: parseUnits((400_000).toString(), 6),
      startTimeOfWarmup: startTimeOfWarmup,
      maxDurationOfWarmup: maxDurationOfWarmup,
      durationOfLockup: week * 8n,
      minDeposit: parseUnits((100).toString(), 6)
    },
    {
      lp: '0xFa334bE13bA4cdc5C3D9A25344FFBb312d2423A2',
      totalReward: parseUnits((100_000).toString(), 18),
      minRaisingTarget: parseUnits((100_000).toString(), 6),
      maxRaisingTarget: parseUnits((400_000).toString(), 6),
      startTimeOfWarmup: startTimeOfWarmup,
      maxDurationOfWarmup: maxDurationOfWarmup,
      durationOfLockup: week * 8n,
      minDeposit: parseUnits((100).toString(), 6)
    },
    {
      lp: '0x9706DE4B4Bb1027ce059344Cd42Bb57E079f64c7',
      totalReward: parseUnits((100_000).toString(), 18),
      minRaisingTarget: parseUnits((100_000).toString(), 6),
      maxRaisingTarget: parseUnits((400_000).toString(), 6),
      startTimeOfWarmup: startTimeOfWarmup,
      maxDurationOfWarmup: maxDurationOfWarmup,
      durationOfLockup: week * 8n,
      minDeposit: parseUnits((100).toString(), 6)
    }
  ]
  for (let config of bpConfigs) {
    await tool.deployBP(config)
  }
}

export default func

func.id = 'deploy_bp' // id required to prevent reexecution
func.tags = ['bp']
