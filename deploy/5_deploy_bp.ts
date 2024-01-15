import { parseEther } from 'ethers'
import type { DeployFunction } from 'hardhat-deploy/types'
import type { HardhatRuntimeEnvironment } from 'hardhat/types'
import { DeployTool } from '~/hardhat/common/DeployTool'
import { BPConfigStruct } from '~/typechain-types/contracts/bp/ChromaticBP'

export function toTimestamp(date: Date) {
  return BigInt(Math.floor(date.getTime() / 1000))
}

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const tool = await DeployTool.createAsync(hre)

  const aday = BigInt(24 * 3600)

  // FIXME this is just sample config

  const bpConfigs: BPConfigStruct[] = [
    // for early boosting
    {
      lp: '0xC2Eed9c6187876965b858Ca9D3501Af0BDA8484E',
      totalReward: parseEther('100'),
      minRaisingTarget: parseEther('500'),
      maxRaisingTarget: parseEther('600'),
      startTimeOfWarmup: toTimestamp(new Date(Date.UTC(2024, 0, 16))),
      maxDurationOfWarmup: aday,
      durationOfLockup: aday
    },
    // for canceled case
    {
      lp: '0xeE441772a1757Ac9a0fe5701B43b1106B09e5A7E',
      totalReward: parseEther('200'),
      minRaisingTarget: parseEther('50000'),
      maxRaisingTarget: parseEther('100000'),
      startTimeOfWarmup: toTimestamp(new Date(Date.UTC(2024, 0, 16))),
      maxDurationOfWarmup: aday * 2n,
      durationOfLockup: aday
    },
    // for above minRaisingTarget but below max ,
    {
      lp: '0x53652F98FfD309D68196c28a4CB700D103750AB0',
      totalReward: parseEther('100'),
      minRaisingTarget: parseEther('300'),
      maxRaisingTarget: parseEther('100000'),
      startTimeOfWarmup: toTimestamp(new Date(Date.UTC(2024, 0, 16))),
      maxDurationOfWarmup: aday * 3n,
      durationOfLockup: aday
    }
  ]
  for (let config of bpConfigs) {
    await tool.deployBP(config)
  }
}

export default func

func.id = 'deploy_bp' // id required to prevent reexecution
func.tags = ['bp']
