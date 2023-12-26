import { Address } from '@graphprotocol/graph-ts'
import { ChromaticBP as ChromaticBP_ } from '../generated/ChromaticBPFactory/ChromaticBP'
import { ChromaticBPCreated as ChromaticBPCreatedEvent } from '../generated/ChromaticBPFactory/ChromaticBPFactory'
import { ChromaticBP, ChromaticBPCreated, ChromaticBPStatus } from '../generated/schema'
import { ChromaticBP as ChromaticBPTemplate } from '../generated/templates'

export function handleChromaticBPCreated(event: ChromaticBPCreatedEvent): void {
  let entity = new ChromaticBPCreated(event.transaction.hash.concatI32(event.logIndex.toI32()))
  entity.lp = event.params.lp
  entity.bp = event.params.bp

  entity.blockNumber = event.block.number
  entity.blockTimestamp = event.block.timestamp
  entity.transactionHash = event.transaction.hash

  entity.save()

  let bpEntity = ChromaticBP.load(entity.bp)
  if (bpEntity == null) {
    let bpContract = ChromaticBP_.bind(Address.fromBytes(entity.bp))

    bpEntity = new ChromaticBP(entity.bp)
    bpEntity.lp = entity.lp
    bpEntity.totalReward = bpContract.totalReward()
    bpEntity.minRaisingTarget = bpContract.minRaisingTarget()
    bpEntity.maxRaisingTarget = bpContract.maxRaisingTarget()
    bpEntity.startTimeOfWarmup = bpContract.startTimeOfWarmup()
    bpEntity.initialEndTimeOfWarmup = bpContract.endTimeOfWarmup()
    bpEntity.save()

    let statusId = entity.bp.toHex() + '@' + event.block.number.toString()
    let statusEntity = ChromaticBPStatus.load(statusId)
    if (statusEntity == null) {
      statusEntity = new ChromaticBPStatus(statusId)
      statusEntity.bp = bpEntity.id
      statusEntity.endTimeOfWarmup = bpContract.endTimeOfWarmup()
      statusEntity.endTimeOfLockup = bpContract.endTimeOfLockup()
      statusEntity.currentPeriod = bpContract.currentPeriod()
      statusEntity.status = bpContract.status()
      statusEntity.blockNumber = event.block.number
      statusEntity.blockTimestamp = event.block.timestamp
      statusEntity.save()
    }
  }

  ChromaticBPTemplate.create(event.params.bp)
}
