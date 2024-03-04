import { defineConfig } from '@wagmi/cli'
import { hardhat } from '@wagmi/cli/plugins'
import { address as bpFactoryArbitrumOne } from '~/deployments/arbitrum_one/ChromaticBPFactory.json'
import { address as registryArbitrumOne } from '~/deployments/arbitrum_one/ChromaticLPRegistry.json'
import { address as bpFactoryArbitrumSepolia } from '~/deployments/arbitrum_sepolia/ChromaticBPFactory.json'
import { address as registryArbitrumSepolia } from '~/deployments/arbitrum_sepolia/ChromaticLPRegistry.json'

export default defineConfig({
  out: 'wagmi/index.ts',
  plugins: [
    hardhat({
      project: '.',
      include: [
        '**/ChromaticLPRegistry.sol/**/*.json',
        '**/IChromaticLP.sol/**/*.json',
        '**/IERC20Metadata.sol/**/*.json',
        '**/ChromaticBPFactory.sol/**/*.json',
        '**/IChromaticBP.sol/**/*.json',
        '**/mate2/AutomateBP.sol/**/*.json',
        '**/mate2/AutomateLP.sol/**/*.json'
      ],
      deployments: {
        ChromaticLPRegistry: {
          421614: registryArbitrumSepolia as `0x${string}`,
          42161: registryArbitrumOne as `0x${string}`
        },
        ChromaticBPFactory: {
          421614: bpFactoryArbitrumSepolia as `0x${string}`,
          42161: bpFactoryArbitrumOne as `0x${string}`
        }
      }
    })
  ]
})
