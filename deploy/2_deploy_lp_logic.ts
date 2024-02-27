import type { DeployFunction } from 'hardhat-deploy/types'
import type { HardhatRuntimeEnvironment } from 'hardhat/types'
import { DeployTool } from '~/hardhat/common/DeployTool'
import { getDefaultLPConfigs } from '~/hardhat/common/LPConfig'

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const tool = await DeployTool.createAsync(hre, getDefaultLPConfigs())
  const commitHash = 'dca513049f54948e2f343b41fa20322a383e538f'.substring(0, 7)
  const result = await tool.deployLPLogic(commitHash)
}

export default func

func.id = 'deploy_lp_logic' // id required to prevent reexecution
func.tags = ['lp_logic']
