import { BPBoostTaskExecuted, BPDeposited } from '../generated/schema'
import {
  BPBoostTaskExecuted as BPBoostTaskExecutedEvent,
  BPDeposited as BPDepositedEvent
} from '../generated/templates/IChromaticBP/IChromaticBP'

export function handleBPDeposited(event: BPDepositedEvent): void {
  let entity = new BPDeposited(event.transaction.hash.concatI32(event.logIndex.toI32()))
  entity.bp = event.address
  entity.provider = event.params.provider
  entity.amount = event.params.amount

  entity.blockNumber = event.block.number
  entity.blockTimestamp = event.block.timestamp
  entity.transactionHash = event.transaction.hash

  entity.save()
}

export function handleBPBoostTaskExecuted(event: BPBoostTaskExecutedEvent): void {
  let entity = new BPBoostTaskExecuted(event.transaction.hash.concatI32(event.logIndex.toI32()))
  entity.bp = event.address

  entity.blockNumber = event.block.number
  entity.blockTimestamp = event.block.timestamp
  entity.transactionHash = event.transaction.hash

  entity.save()
}
