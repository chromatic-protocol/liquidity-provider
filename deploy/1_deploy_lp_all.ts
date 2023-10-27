import type { DeployFunction } from 'hardhat-deploy/types'
import { DeployResult } from 'hardhat-deploy/types'
import type { HardhatRuntimeEnvironment } from 'hardhat/types'
import { DeployTool } from '~/hardhat/common/DeployTool'
import { getDefaultLPConfigs } from '~/hardhat/common/LPConfig'

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const tool = await DeployTool.createAsync(hre, getDefaultLPConfigs())
  const result = await tool.deployAllLP()
  const deployedResults: DeployResult[] = [].concat(...Object.values(result))
  for (let deployed of deployedResults) {
    await tool.registerLP(deployed.address)
  }
}

export default func

func.id = 'deploy_lp_all' // id required to prevent reexecution
func.tags = ['lp_all']
