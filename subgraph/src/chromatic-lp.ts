import { AddLiquiditySettled, RemoveLiquiditySettled } from '../generated/schema'
import {
  AddLiquiditySettled as AddLiquiditySettledEvent,
  RemoveLiquiditySettled as RemoveLiquiditySettledEvent
} from '../generated/templates/IChromaticLP/IChromaticLP'

export function handleAddLiquiditySettled(event: AddLiquiditySettledEvent): void {
  let entity = new AddLiquiditySettled(event.transaction.hash.concatI32(event.logIndex.toI32()))
  entity.lp = event.address
  entity.receiptId = event.params.receiptId
  entity.settlementAdded = event.params.settlementAdded
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
  entity.burningAmount = event.params.burningAmount
  entity.witdrawnSettlementAmount = event.params.witdrawnSettlementAmount
  entity.refundedAmount = event.params.refundedAmount

  entity.blockNumber = event.block.number
  entity.blockTimestamp = event.block.timestamp
  entity.transactionHash = event.transaction.hash

  entity.save()
}
