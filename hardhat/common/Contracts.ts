import { deployedAddress } from '@chromatic-protocol/sdk-ethers-v6'
import {
  ChromaticMarketFactory,
  ChromaticMarketFactory__factory,
  IChromaticMarket,
  IChromaticMarket__factory
} from '@chromatic-protocol/sdk-ethers-v6/contracts'
import { Signer } from 'ethers'
import type { HardhatRuntimeEnvironment } from 'hardhat/types'
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
  IMate2AutomationRegistry,
  IMate2AutomationRegistry__factory
} from '~/typechain-types'

export class Contracts {
  constructor(
    public readonly hre: HardhatRuntimeEnvironment,
    public readonly signer: Signer,
    public readonly deployed: DeployedStore
  ) {}

  get networkName() {
    if (this.hre.network.name == 'anvil_arbitrum') {
      return 'anvil'
    } else {
      return this.hre.network.name
    }
  }

  get marketFactory(): ChromaticMarketFactory {
    const address = deployedAddress[this.networkName]['ChromaticMarketFactory']
    return ChromaticMarketFactory__factory.connect(address, this.signer)
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
}
