import { Address, ethereum } from '@graphprotocol/graph-ts'
import {
  AddLiquidity,
  AddLiquiditySettled,
  ChromaticLPConfig,
  ChromaticLPMeta,
  ChromaticLPStat,
  LPTokenTotalSupply,
  RebalanceAddLiquidity,
  RebalanceRemoveLiquidity,
  RebalanceSettled,
  RemoveLiquidity,
  RemoveLiquiditySettled
} from '../generated/schema'
import {
  AddLiquidity as AddLiquidityEvent,
  AddLiquiditySettled as AddLiquiditySettledEvent,
  ChromaticLP,
  RebalanceAddLiquidity as RebalanceAddLiquidityEvent,
  RebalanceRemoveLiquidity as RebalanceRemoveLiquidityEvent,
  RebalanceSettled as RebalanceSettledEvent,
  RemoveLiquidity as RemoveLiquidityEvent,
  RemoveLiquiditySettled as RemoveLiquiditySettledEvent,
  SetAutomationFeeReserved as SetAutomationFeeReservedEvent,
  SetLpName as SetLpNameEvent,
  SetLpTag as SetLpTagEvent,
  SetMinHoldingValueToRebalance as SetMinHoldingValueToRebalanceEvent,
  Transfer as TransferEvent
} from '../generated/templates/ChromaticLP/ChromaticLP'

export function handleAddLiquidity(event: AddLiquidityEvent): void {
  let entity = new AddLiquidity(event.transaction.hash.concatI32(event.logIndex.toI32()))
  entity.lp = event.address
  entity.receiptId = event.params.receiptId
  entity.provider = event.params.provider
  entity.recipient = event.params.recipient
  entity.oracleVersion = event.params.oracleVersion
  entity.amount = event.params.amount

  entity.blockNumber = event.block.number
  entity.blockTimestamp = event.block.timestamp
  entity.transactionHash = event.transaction.hash

  entity.save()
  saveChromaticLPStat(event)
}

export function handleAddLiquiditySettled(event: AddLiquiditySettledEvent): void {
  let entity = new AddLiquiditySettled(event.transaction.hash.concatI32(event.logIndex.toI32()))
  entity.lp = event.address
  entity.receiptId = event.params.receiptId
  entity.provider = event.params.provider
  entity.recipient = event.params.recipient
  entity.settlementAdded = event.params.settlementAdded
  entity.lpTokenAmount = event.params.lpTokenAmount
  entity.keeperFee = event.params.keeperFee

  entity.blockNumber = event.block.number
  entity.blockTimestamp = event.block.timestamp
  entity.transactionHash = event.transaction.hash

  entity.save()
  saveChromaticLPStat(event)
}

export function handleRemoveLiquidity(event: RemoveLiquidityEvent): void {
  let entity = new RemoveLiquidity(event.transaction.hash.concatI32(event.logIndex.toI32()))
  entity.lp = event.address
  entity.receiptId = event.params.receiptId
  entity.provider = event.params.provider
  entity.recipient = event.params.recipient
  entity.oracleVersion = event.params.oracleVersion
  entity.lpTokenAmount = event.params.lpTokenAmount

  entity.blockNumber = event.block.number
  entity.blockTimestamp = event.block.timestamp
  entity.transactionHash = event.transaction.hash

  entity.save()
  saveChromaticLPStat(event)
}

export function handleRemoveLiquiditySettled(event: RemoveLiquiditySettledEvent): void {
  let entity = new RemoveLiquiditySettled(event.transaction.hash.concatI32(event.logIndex.toI32()))
  entity.lp = event.address
  entity.receiptId = event.params.receiptId
  entity.provider = event.params.provider
  entity.recipient = event.params.recipient
  entity.burningAmount = event.params.burningAmount
  entity.withdrawnSettlementAmount = event.params.withdrawnSettlementAmount
  entity.refundedAmount = event.params.refundedAmount
  entity.keeperFee = event.params.keeperFee

  entity.blockNumber = event.block.number
  entity.blockTimestamp = event.block.timestamp
  entity.transactionHash = event.transaction.hash

  entity.save()
  saveChromaticLPStat(event)
}

export function handleRebalanceAddLiquidity(event: RebalanceAddLiquidityEvent): void {
  let entity = new RebalanceAddLiquidity(event.transaction.hash.concatI32(event.logIndex.toI32()))
  entity.lp = event.address
  entity.receiptId = event.params.receiptId
  entity.oracleVersion = event.params.oracleVersion
  entity.amount = event.params.amount
  entity.currentUtility = event.params.currentUtility

  entity.blockNumber = event.block.number
  entity.blockTimestamp = event.block.timestamp
  entity.transactionHash = event.transaction.hash

  entity.save()
  saveChromaticLPStat(event)
}

export function handleRebalanceRemoveLiquidity(event: RebalanceRemoveLiquidityEvent): void {
  let entity = new RebalanceRemoveLiquidity(
    event.transaction.hash.concatI32(event.logIndex.toI32())
  )
  entity.lp = event.address
  entity.receiptId = event.params.receiptId
  entity.oracleVersion = event.params.oracleVersion
  entity.currentUtility = event.params.currentUtility

  entity.blockNumber = event.block.number
  entity.blockTimestamp = event.block.timestamp
  entity.transactionHash = event.transaction.hash

  entity.save()
  saveChromaticLPStat(event)
}

export function handleRebalanceSettled(event: RebalanceSettledEvent): void {
  let entity = new RebalanceSettled(event.transaction.hash.concatI32(event.logIndex.toI32()))
  entity.lp = event.address
  entity.receiptId = event.params.receiptId
  entity.keeperFee = event.params.keeperFee

  entity.blockNumber = event.block.number
  entity.blockTimestamp = event.block.timestamp
  entity.transactionHash = event.transaction.hash

  entity.save()
  saveChromaticLPStat(event)
}

function saveChromaticLPStat(event: ethereum.Event): void {
  let id = event.address.toHex() + '@' + event.block.number.toString()
  let entity = ChromaticLPStat.load(id)
  if (entity == null) {
    let lpContract = ChromaticLP.bind(event.address)
    let valueInfo = lpContract.valueInfo()
    let valueOfSupply = lpContract.try_valueOfSupply()

    entity = new ChromaticLPStat(id)
    entity.lp = lpContract._address
    entity.totalValue = valueInfo.total
    entity.holdingValue = valueInfo.holding
    entity.pendingValue = valueInfo.pending
    entity.holdingClbValue = valueInfo.holdingClb
    entity.pendingClbValue = valueInfo.pendingClb
    if (!valueOfSupply.reverted) {
      entity.valueOfSupply = valueOfSupply.value
    }
    entity.utilization = lpContract.utilization()
    entity.blockNumber = event.block.number
    entity.blockTimestamp = event.block.timestamp
    entity.save()
  }
}

export function handleSetLpName(event: SetLpNameEvent): void {
  saveChromaticLPMeta(event)
}

export function handleSetLpTag(event: SetLpTagEvent): void {
  saveChromaticLPMeta(event)
}

function saveChromaticLPMeta(event: ethereum.Event): void {
  let id = event.address.toHex() + '@' + event.block.number.toString()
  let entity = ChromaticLPMeta.load(id)
  if (entity == null) {
    let lpContract = ChromaticLP.bind(event.address)

    entity = new ChromaticLPMeta(id)
    entity.lp = lpContract._address
    entity.lpName = lpContract.lpName()
    entity.lpTag = lpContract.lpTag()
    entity.blockNumber = event.block.number
    entity.blockTimestamp = event.block.timestamp
    entity.save()
  }
}

export function handleSetAutomationFeeReserved(event: SetAutomationFeeReservedEvent): void {
  saveChromaticLPConfig(event)
}

export function handleSetMinHoldingValueToRebalance(
  event: SetMinHoldingValueToRebalanceEvent
): void {
  saveChromaticLPConfig(event)
}

function saveChromaticLPConfig(event: ethereum.Event): void {
  let id = event.address.toHex() + '@' + event.block.number.toString()
  let entity = ChromaticLPConfig.load(id)
  if (entity == null) {
    let lpContract = ChromaticLP.bind(event.address)

    entity = new ChromaticLPConfig(id)
    entity.lp = lpContract._address
    entity.automationFeeReserved = lpContract.automationFeeReserved()
    entity.minHoldingValueToRebalance = lpContract.minHoldingValueToRebalance()
    entity.blockNumber = event.block.number
    entity.blockTimestamp = event.block.timestamp
    entity.save()
  }
}

export function handleTransfer(event: TransferEvent): void {
  if (event.params.from == Address.zero() || event.params.to == Address.zero()) {
    let id = event.address.toHex() + '@' + event.block.number.toString()
    let entity = LPTokenTotalSupply.load(id)
    if (entity == null) {
      let lpContract = ChromaticLP.bind(event.address)

      entity = new LPTokenTotalSupply(id)
      entity.token = lpContract._address
      entity.amount = lpContract.totalSupply()
      entity.blockNumber = event.block.number
      entity.blockTimestamp = event.block.timestamp
      entity.save()
    }
  }
}
