import { Client } from '@chromatic-protocol/liquidity-provider-sdk'
import { HardhatRuntimeEnvironment } from 'hardhat/types'
import type { WalletClient } from 'viem'
export { Client }

export async function getSDKClient(hre: HardhatRuntimeEnvironment, walletClient?: WalletClient) {
  if (!walletClient) [walletClient] = await hre.viem.getWalletClients()
  const publicClient = await hre.viem.getPublicClient()

  return new Client({ publicClient, walletClient })
}
