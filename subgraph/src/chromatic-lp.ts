import { BigInt } from '@graphprotocol/graph-ts'
import {
  AddLiquidity,
  AddLiquiditySettled,
  RebalanceAddLiquidity,
  RebalanceRemoveLiquidity,
  RebalanceSettled,
  RemoveLiquidity,
  RemoveLiquiditySettled
} from '../generated/schema'
import {
  AddLiquidity as AddLiquidityEvent,
  AddLiquiditySettled as AddLiquiditySettledEvent,
  RebalanceAddLiquidity as RebalanceAddLiquidityEvent,
  RebalanceRemoveLiquidity as RebalanceRemoveLiquidityEvent,
  RebalanceSettled as RebalanceSettledEvent,
  RemoveLiquidity as RemoveLiquidityEvent,
  RemoveLiquiditySettled as RemoveLiquiditySettledEvent
} from '../generated/templates/IChromaticLP/IChromaticLP'

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
}
