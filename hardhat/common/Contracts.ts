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
  IAutomateMate2BP,
  IAutomateMate2BP__factory,
  IAutomateMate2LP,
  IAutomateMate2LP__factory,
  IChromaticBP,
  IChromaticBP__factory,
  IChromaticLP,
  IChromaticLP__factory,
  IERC20Metadata,
  IERC20Metadata__factory,
  IMate2AutomationRegistry,
  IMate2AutomationRegistry__factory
} from '~/typechain-types'

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
  mate2Registry(address: string): IMate2AutomationRegistry {
    return IMate2AutomationRegistry__factory.connect(address, this.signer)
  }
  automateLP(address: string): IAutomateMate2LP {
    return IAutomateMate2LP__factory.connect(address, this.signer)
  }
  automateBP(address: string): IAutomateMate2BP {
    return IAutomateMate2BP__factory.connect(address, this.signer)
  }
}
