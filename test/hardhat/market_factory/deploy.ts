import {
  ChromaticLiquidator,
  ChromaticMarketFactory,
  ChromaticVault,
  KeeperFeePayerMock
} from '@chromatic/typechain-types'
import { CHAIN_ID, GELATO_ADDRESSES } from '@gelatonetwork/automate-sdk'
import { Contract, ZeroAddress, parseEther } from 'ethers'
import { ethers } from 'hardhat'
import { deployContract } from '../utils'

export async function deploy() {
  const [deployer] = await ethers.getSigners()

  const clbTokenDeployerLib = await deployContract<Contract>('CLBTokenDeployerLib')
  const marketDeployerLib = await deployContract<Contract>('MarketDeployerLib', {
    libraries: {
      CLBTokenDeployerLib: await clbTokenDeployerLib.getAddress()
    }
  })

  const marketDiamondCutFacet = await deployContract<Contract>('MarketDiamondCutFacet')
  const marketLoupeFacet = await deployContract<Contract>('DiamondLoupeFacet')
  const marketStateFacet = await deployContract<Contract>('MarketStateFacet')
  const marketLiquidityFacet = await deployContract<Contract>('MarketLiquidityFacet')
  const marketLiquidityLensFacet = await deployContract<Contract>('MarketLiquidityLensFacet')
  const marketTradeFacet = await deployContract<Contract>('MarketTradeFacet')
  const marketLiquidateFacet = await deployContract<Contract>('MarketLiquidateFacet')
  const marketSettleFacet = await deployContract<Contract>('MarketSettleFacet')

  const marketFactory = await deployContract<ChromaticMarketFactory>('ChromaticMarketFactory', {
    args: [
      await marketDiamondCutFacet.getAddress(),
      await marketLoupeFacet.getAddress(),
      await marketStateFacet.getAddress(),
      await marketLiquidityFacet.getAddress(),
      await marketLiquidityLensFacet.getAddress(),
      await marketTradeFacet.getAddress(),
      await marketLiquidateFacet.getAddress(),
      await marketSettleFacet.getAddress()
    ],
    libraries: {
      MarketDeployerLib: await marketDeployerLib.getAddress()
    }
  })

  const keeperFeePayer = await deployContract<KeeperFeePayerMock>('KeeperFeePayerMock', {
    args: [await marketFactory.getAddress()]
  })
  await (await marketFactory.setKeeperFeePayer(keeperFeePayer.getAddress())).wait()
  await (
    await deployer.sendTransaction({
      to: keeperFeePayer.getAddress(),
      value: parseEther('5')
    })
  ).wait()

  const vault = await deployContract<ChromaticVault>('ChromaticVault', {
    args: [
      await marketFactory.getAddress(),
      GELATO_ADDRESSES[CHAIN_ID.ARBITRUM_GOERLI].automate,
      ZeroAddress
    ]
  })
  await (await marketFactory.setVault(vault.getAddress())).wait()

  const liquidator = await deployContract<ChromaticLiquidator>('ChromaticLiquidator', {
    args: [
      await marketFactory.getAddress(),
      GELATO_ADDRESSES[CHAIN_ID.ARBITRUM_GOERLI].automate,
      ZeroAddress
    ]
  })
  await (await marketFactory.setLiquidator(liquidator.getAddress())).wait()

  return { marketFactory, keeperFeePayer, liquidator }
}
