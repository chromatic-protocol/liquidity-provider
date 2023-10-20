import { parseEther, formatEther } from "viem";
import hre from "hardhat";
import { HardhatRuntimeEnvironment } from "hardhat/types";
import type { PublicClient, WalletClient } from "viem";
import { Client } from "@chromatic-protocol/liquidity-provider-sdk";
export { Client }

export async function getSDKClient(hre: HardhatRuntimeEnvironment, walletClient?: WalletClient) {

    if (!walletClient)
        [walletClient,] = await hre.viem.getWalletClients();
    const publicClient = await hre.viem.getPublicClient();

    return new Client({ publicClient, walletClient })
}