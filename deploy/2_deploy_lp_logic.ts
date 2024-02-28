import type { DeployFunction } from 'hardhat-deploy/types'
import type { HardhatRuntimeEnvironment } from 'hardhat/types'
import { DeployTool } from '~/hardhat/common/DeployTool'
import { getDefaultLPConfigs } from '~/hardhat/common/LPConfig'

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const tool = await DeployTool.createAsync(hre, getDefaultLPConfigs())
  const commitHash = '5b34fc53cb22dd137191a8faf4df7c24043821cc'.substring(0, 7)
  const result = await tool.deployLPLogic(commitHash)
}

export default func

func.id = 'deploy_lp_logic' // id required to prevent reexecution
func.tags = ['lp_logic']
