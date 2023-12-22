import { Address } from '@graphprotocol/graph-ts'
import { ChromaticLPRegistered as ChromaticLPRegisteredEvent } from '../generated/ChromaticLPRegistry/ChromaticLPRegistry'
import { IChromaticLP as IChromaticLP_ } from '../generated/ChromaticLPRegistry/IChromaticLP'
import { IChromaticMarket } from '../generated/ChromaticLPRegistry/IChromaticMarket'
import { IERC20Metadata } from '../generated/ChromaticLPRegistry/IERC20Metadata'
import { IOracleProvider } from '../generated/ChromaticLPRegistry/IOracleProvider'
import { ChromaticLP, ChromaticLPRegistered } from '../generated/schema'
import { IChromaticLP } from '../generated/templates'

export function handleChromaticLPRegistered(event: ChromaticLPRegisteredEvent): void {
  let entity = new ChromaticLPRegistered(event.transaction.hash.concatI32(event.logIndex.toI32()))
  entity.market = event.params.market
  entity.lp = event.params.lp

  entity.blockNumber = event.block.number
  entity.blockTimestamp = event.block.timestamp
  entity.transactionHash = event.transaction.hash

  entity.save()

  let lpEntity = ChromaticLP.load(entity.lp)
  if (lpEntity == null) {
    let lpContract = IChromaticLP_.bind(Address.fromBytes(entity.lp))
    let lpTokenContract = IERC20Metadata.bind(Address.fromBytes(entity.lp))
    let marketContract = IChromaticMarket.bind(Address.fromBytes(entity.market))
    let tokenContract = IERC20Metadata.bind(marketContract.settlementToken())
    let providerContract = IOracleProvider.bind(marketContract.oracleProvider())

    lpEntity = new ChromaticLP(lpContract._address)
    lpEntity.lpName = lpContract.lpName()
    lpEntity.longShortInfo = lpContract.longShortInfo()
    lpEntity.market = marketContract._address
    lpEntity.settlementToken = tokenContract._address
    lpEntity.settlementTokenSymbol = tokenContract.symbol()
    lpEntity.settlementTokenDecimals = tokenContract.decimals()
    lpEntity.oracleProvider = providerContract._address
    lpEntity.oracleDescription = providerContract.description()
    lpEntity.lpTag = lpContract.lpTag()
    lpEntity.feeRates = lpContract.feeRates()
    lpEntity.clbTokenIds = lpContract.clbTokenIds()
    lpEntity.lpTokenName = lpTokenContract.name()
    lpEntity.lpTokenSymbol = lpTokenContract.symbol()
    lpEntity.lpTokenDecimals = lpTokenContract.decimals()
    lpEntity.distributionRates = lpContract.distributionRates()
    lpEntity.rebalanceBPS = lpContract.rebalanceBPS()
    lpEntity.rebalanceCheckingInterval = lpContract.rebalanceCheckingInterval()
    lpEntity.utilizationTargetBPS = lpContract.utilizationTargetBPS()

    lpEntity.save()
  }

  IChromaticLP.create(event.params.lp)
}
