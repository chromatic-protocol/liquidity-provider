import { ChromaticBPCreated as ChromaticBPCreatedEvent } from '../generated/ChromaticBPFactory/ChromaticBPFactory'
import { ChromaticBPCreated } from '../generated/schema'
import { IChromaticBP } from '../generated/templates'

export function handleChromaticBPCreated(event: ChromaticBPCreatedEvent): void {
  let entity = new ChromaticBPCreated(event.transaction.hash.concatI32(event.logIndex.toI32()))
  entity.lp = event.params.lp
  entity.bp = event.params.bp

  entity.blockNumber = event.block.number
  entity.blockTimestamp = event.block.timestamp
  entity.transactionHash = event.transaction.hash

  entity.save()

  IChromaticBP.create(event.params.bp)
}
