import type { DeployFunction } from 'hardhat-deploy/types'
import type { HardhatRuntimeEnvironment } from 'hardhat/types'
import { DeployTool } from '~/hardhat/common/DeployTool'

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const tool = await DeployTool.createAsync(hre)
  await tool.deployAutomateBP()
}

export default func

func.id = 'deploy_automate_bp' // id required to prevent reexecution
func.tags = ['automate_bp']
