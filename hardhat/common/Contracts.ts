import { chromaticMarketFactoryAddress } from '@chromatic-protocol/sdk-viem'
import { Signer } from 'ethers'
import type { HardhatRuntimeEnvironment } from 'hardhat/types'
import {
  IChromaticMarket,
  IChromaticMarketFactory,
  IChromaticMarketFactory__factory,
  IChromaticMarket__factory
} from '~/typechain-types'
import { DeployedStore } from './DeployedStore'

import {
  ChromaticBPFactory,
  ChromaticBPFactory__factory,
  ChromaticLPRegistry,
  ChromaticLPRegistry__factory,
  IChromaticBP,
  IChromaticBP__factory,
  IChromaticLP,
  IChromaticLP__factory,
  IERC20Metadata,
  IERC20Metadata__factory,
  IMate2AutomationRegistry1_1,
  IMate2AutomationRegistry1_1__factory
} from '~/typechain-types'

import { AutomateBP, AutomateLP } from '~/typechain-types/contracts/automation/mate2'
import {
  AutomateBP__factory,
  AutomateLP__factory
} from '~/typechain-types/factories/contracts/automation/mate2'

export class Contracts {
  constructor(
    public readonly hre: HardhatRuntimeEnvironment,
    public readonly signer: Signer,
    public readonly deployed: DeployedStore
  ) {}

  get chainId(): number {
    if (this.hre.network.name == 'anvil_arbitrum') {
      return this.hre.config.networks.arbitrum_sepolia.chainId!
    } else {
      return this.hre.network.config.chainId!
    }
  }

  get marketFactory(): IChromaticMarketFactory {
    const address =
      chromaticMarketFactoryAddress[this.chainId as keyof typeof chromaticMarketFactoryAddress]

    console.assert(address, `check marketFactory deployed address available in ${this.chainId}`)
    return IChromaticMarketFactory__factory.connect(address, this.signer)
  }

  get lpRegistry(): ChromaticLPRegistry {
    const address = this.deployed.registry
    if (!address) throw new Error('deployed registry not exist')
    return ChromaticLPRegistry__factory.connect(address, this.signer)
  }
  get bpFactory(): ChromaticBPFactory {
    const address = this.deployed.bpFactory
    if (!address) throw new Error('deployed bpFactory not exist')
    return ChromaticBPFactory__factory.connect(address, this.signer)
  }
  lp(address: string): IChromaticLP {
    return IChromaticLP__factory.connect(address, this.signer)
  }
  bp(address: string): IChromaticBP {
    return IChromaticBP__factory.connect(address, this.signer)
  }

  erc20(address: string): IERC20Metadata {
    return IERC20Metadata__factory.connect(address, this.signer)
  }
  market(address: string): IChromaticMarket {
    return IChromaticMarket__factory.connect(address, this.signer)
  }
  mate2Registry(address: string): IMate2AutomationRegistry1_1 {
    return IMate2AutomationRegistry1_1__factory.connect(address, this.signer)
  }
  automateLP(address: string): AutomateLP {
    return AutomateLP__factory.connect(address, this.signer)
  }
  automateBP(address: string): AutomateBP {
    return AutomateBP__factory.connect(address, this.signer)
  }
}
