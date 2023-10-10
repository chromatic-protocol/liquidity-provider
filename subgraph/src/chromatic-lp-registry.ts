import { ChromaticLPRegistered as ChromaticLPRegisteredEvent } from '../generated/ChromaticLPRegistry/ChromaticLPRegistry'
import { ChromaticLPRegistered } from '../generated/schema'
import { IChromaticLP } from './../generated/templates'

export function handleChromaticLPRegistered(event: ChromaticLPRegisteredEvent): void {
  let entity = new ChromaticLPRegistered(event.transaction.hash.concatI32(event.logIndex.toI32()))
  entity.market = event.params.market
  entity.lp = event.params.lp

  entity.blockNumber = event.block.number
  entity.blockTimestamp = event.block.timestamp
  entity.transactionHash = event.transaction.hash

  entity.save()

  IChromaticLP.create(event.params.lp)
}
