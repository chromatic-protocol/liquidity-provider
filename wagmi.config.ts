import { defineConfig } from '@wagmi/cli'
import { hardhat } from '@wagmi/cli/plugins'
import { address as registryAddress } from '~/deployments/arbitrum_goerli/ChromaticLPRegistry.json'

export default defineConfig({
  out: 'wagmi/index.ts',
  plugins: [
    hardhat({
      project: '.',
      include: ['ChromaticLPRegistry', 'ChromaticLP*', 'IERC20Metadata'],
      deployments: {
        ChromaticLPRegistry: {
          421613: registryAddress as `0x${string}`
        }
      }
    })
  ]
})
