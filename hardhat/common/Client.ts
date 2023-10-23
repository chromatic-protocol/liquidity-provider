import { Client } from '@chromatic-protocol/liquidity-provider-sdk'
import { HardhatRuntimeEnvironment } from 'hardhat/types'
import type { WalletClient } from 'viem'
import { AddressType } from './types'
export { Client }

export async function getSDKClient(hre: HardhatRuntimeEnvironment, walletClient?: WalletClient) {
  if (!walletClient) [walletClient] = await hre.viem.getWalletClients()
  const publicClient = await hre.viem.getPublicClient()

  return new Client({ publicClient, walletClient })
}

export async function getLPClient(
  hre: HardhatRuntimeEnvironment,
  walletClient?: WalletClient,
  address?: AddressType
) {
  if (!walletClient) [walletClient] = await hre.viem.getWalletClients()

  return await LPClient.createAsync(hre, walletClient, address)
}

export class LPClient {
  public client: Client
  public address?: AddressType

  static async createAsync(
    hre: HardhatRuntimeEnvironment,
    walletClient?: WalletClient,
    address?: AddressType
  ) {
    if (!walletClient) [walletClient] = await hre.viem.getWalletClients()
    const publicClient = await hre.viem.getPublicClient()
    return new LPClient({
      client: new Client({ publicClient, walletClient }),
      address
    })
  }

  constructor({ client, address }: { client: Client; address?: AddressType }) {
    this.client = client
    this.address = address
  }

  connect(address: AddressType) {
    return new LPClient({ client: this.client, address })
  }

  async contract() {
    return this.client.lp().contracts().lp(this.address!)
  }
  async settlementToken() {
    return await this.client.lp().contracts().settlementToken(this.address!)
  }
  async lpToken() {
    return await this.client.lp().contracts().lpToken(this.address!)
  }
}
