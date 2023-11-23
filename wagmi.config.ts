import { defineConfig } from '@wagmi/cli'
import { hardhat } from '@wagmi/cli/plugins'
import { address as bpFactoryArbitrumGoerli } from '~/deployments/arbitrum_goerli/ChromaticBPFactory.json'
import { address as registryArbitrumGoerli } from '~/deployments/arbitrum_goerli/ChromaticLPRegistry.json'

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
        '**/IChromaticBP.sol/**/*.json'
      ],
      deployments: {
        ChromaticLPRegistry: {
          421613: registryArbitrumGoerli as `0x${string}`
        },
        ChromaticBPFactory: {
          421613: bpFactoryArbitrumGoerli as `0x${string}`
        }
      }
    })
  ]
})
