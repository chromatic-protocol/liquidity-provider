import { BPDeposited, BPExecuted } from '../generated/schema'
import {
  BPDeposited as BPDepositedEvent,
  BPExecuted as BPExecutedEvent
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

export function handleBPExecuted(event: BPExecutedEvent): void {
  let entity = new BPExecuted(event.transaction.hash.concatI32(event.logIndex.toI32()))
  entity.bp = event.address

  entity.blockNumber = event.block.number
  entity.blockTimestamp = event.block.timestamp
  entity.transactionHash = event.transaction.hash

  entity.save()
}
