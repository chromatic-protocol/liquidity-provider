import type { DeployFunction } from 'hardhat-deploy/types'
import type { HardhatRuntimeEnvironment } from 'hardhat/types'
import { DeployTool, type LPConfig } from '~/hardhat/common/DeployTool'

const LP_CONFIG: LPConfig = {
  config: {
    utilizationTargetBPS: 5000,
    rebalanceBPS: 500,
    rebalnceCheckingInterval: 1 * 60 * 60, // 1 hours
    settleCheckingInterval: 1 * 60 // 1 minutes
  },
  feeRates: [-4, -3, -2, -1, 1, 2, 3, 4],
  distributionRates: [2000, 1500, 1000, 500, 500, 1000, 1500, 2000]
}

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const tool = await DeployTool.createAsync(hre)
  await tool.deployAllLP(LP_CONFIG)
}

export default func

func.id = 'deploy_lp_all' // id required to prevent reexecution
func.tags = ['lp_all']
