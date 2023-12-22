import { Address } from '@graphprotocol/graph-ts'
import { ChromaticLP as ChromaticLP_ } from '../generated/ChromaticLPRegistry/ChromaticLP'
import { ChromaticLPRegistered as ChromaticLPRegisteredEvent } from '../generated/ChromaticLPRegistry/ChromaticLPRegistry'
import { IChromaticMarket } from '../generated/ChromaticLPRegistry/IChromaticMarket'
import { IERC20Metadata } from '../generated/ChromaticLPRegistry/IERC20Metadata'
import { IOracleProvider } from '../generated/ChromaticLPRegistry/IOracleProvider'
import {
  ChromaticLP,
  ChromaticLPConfig,
  ChromaticLPMeta,
  ChromaticLPRegistered
} from '../generated/schema'
import { ChromaticLP as ChromaticLPTemplate } from '../generated/templates'

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
    let lpContract = ChromaticLP_.bind(Address.fromBytes(entity.lp))
    let marketContract = IChromaticMarket.bind(Address.fromBytes(entity.market))
    let tokenContract = IERC20Metadata.bind(marketContract.settlementToken())
    let providerContract = IOracleProvider.bind(marketContract.oracleProvider())

    lpEntity = new ChromaticLP(lpContract._address)
    lpEntity.longShortInfo = lpContract.longShortInfo()
    lpEntity.market = marketContract._address
    lpEntity.settlementToken = tokenContract._address
    lpEntity.settlementTokenSymbol = tokenContract.symbol()
    lpEntity.settlementTokenDecimals = tokenContract.decimals()
    lpEntity.oracleProvider = providerContract._address
    lpEntity.oracleDescription = providerContract.description()
    lpEntity.feeRates = lpContract.feeRates()
    lpEntity.clbTokenIds = lpContract.clbTokenIds()
    lpEntity.lpTokenName = lpContract.name()
    lpEntity.lpTokenSymbol = lpContract.symbol()
    lpEntity.lpTokenDecimals = lpContract.decimals()
    lpEntity.distributionRates = lpContract.distributionRates()
    lpEntity.rebalanceBPS = lpContract.rebalanceBPS()
    lpEntity.rebalanceCheckingInterval = lpContract.rebalanceCheckingInterval()
    lpEntity.utilizationTargetBPS = lpContract.utilizationTargetBPS()

    lpEntity.save()

    let id = entity.lp.toHex() + '@' + event.block.number.toString()

    let metaEntity = ChromaticLPMeta.load(id)
    if (metaEntity == null) {
      metaEntity = new ChromaticLPMeta(id)
      metaEntity.lp = lpContract._address
      metaEntity.lpName = lpContract.lpName()
      metaEntity.lpTag = lpContract.lpTag()
      metaEntity.blockNumber = event.block.number
      metaEntity.blockTimestamp = event.block.timestamp
      metaEntity.save()
    }

    let configEntity = ChromaticLPConfig.load(id)
    if (configEntity == null) {
      configEntity = new ChromaticLPConfig(id)
      configEntity.lp = lpContract._address
      configEntity.automationFeeReserved = lpContract.automationFeeReserved()
      configEntity.minHoldingValueToRebalance = lpContract.minHoldingValueToRebalance()
      configEntity.blockNumber = event.block.number
      configEntity.blockTimestamp = event.block.timestamp
      configEntity.save()
    }
  }

  ChromaticLPTemplate.create(event.params.lp)
}
