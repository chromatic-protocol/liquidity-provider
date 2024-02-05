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
    {
      lp: '0x538CbcFa0d6013DE1C75de30F08F416033D543F0',
      totalReward: parseEther('100'),
      minRaisingTarget: parseEther('500'),
      maxRaisingTarget: parseEther('600'),
      startTimeOfWarmup: toTimestamp(new Date(Date.now() + 60000)),
      maxDurationOfWarmup: aday,
      durationOfLockup: aday,
      minDeposit: parseEther('100')
    },
    {
      lp: '0x98F315bBE115F1Ef5fC049FdcA8fAfd8C74ef49E',
      totalReward: parseEther('200'),
      minRaisingTarget: parseEther('500'),
      maxRaisingTarget: parseEther('600'),
      startTimeOfWarmup: toTimestamp(new Date(Date.now() + 60000)),
      maxDurationOfWarmup: aday,
      durationOfLockup: aday,
      minDeposit: parseEther('100')
    },
    {
      lp: '0xA0ae1aC42B325913D8a2FF23F8e8030c5E6B6F2e',
      totalReward: parseEther('100'),
      minRaisingTarget: parseEther('300'),
      maxRaisingTarget: parseEther('400'),
      startTimeOfWarmup: toTimestamp(new Date(Date.now() + 60000)),
      maxDurationOfWarmup: aday * 2n,
      durationOfLockup: aday,
      minDeposit: parseEther('100')
    }
  ]
  for (let config of bpConfigs) {
    await tool.deployBP(config)
  }
}

export default func

func.id = 'deploy_bp' // id required to prevent reexecution
func.tags = ['bp']
