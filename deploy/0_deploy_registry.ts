import { DeployTool } from '@chromatic/hardhat/common/DeployTool'
import type { DeployFunction } from 'hardhat-deploy/types'
import type { HardhatRuntimeEnvironment } from 'hardhat/types'

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const tool = await DeployTool.createAsync(hre)
  await tool.deployRegistry()
}

export default func

func.id = 'deploy_registry' // id required to prevent reexecution
func.tags = ['registry']
