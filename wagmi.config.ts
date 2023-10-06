import { defineConfig } from '@wagmi/cli'
import { hardhat } from '@wagmi/cli/plugins'
import { address as registryArbitrumGoerli } from '~/deployments/arbitrum_goerli/ChromaticLPRegistry.json'
import { address as registryMantleTestnet } from '~/deployments/mantle_testnet/ChromaticLPRegistry.json'

export default defineConfig({
  out: 'wagmi/index.ts',
  plugins: [
    hardhat({
      project: '.',
      include: [
        '**/ChromaticLPRegistry.sol/**/*.json',
        '**/IChromaticLP.sol/**/*.json',
        '**/IERC20Metadata.sol/**/*.json'
      ],
      deployments: {
        ChromaticLPRegistry: {
          5001: registryMantleTestnet as `0x${string}`,
          421613: registryArbitrumGoerli as `0x${string}`
        }
      }
    })
  ]
})
