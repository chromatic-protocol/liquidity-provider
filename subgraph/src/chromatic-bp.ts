import { Address, ethereum } from '@graphprotocol/graph-ts'
import {
  BPBoostTaskExecuted,
  BPDeposited,
  BPSettleUpdated,
  BPCanceled,
  ChromaticBPClaim,
  ChromaticBPDeposit,
  ChromaticBPRefund,
  ChromaticBPStatus,
  ChromaticBPTotalRaised
} from '../generated/schema'
import {
  BPBoostTaskCreated as BPBoostTaskCreatedEvent,
  BPBoostTaskExecuted as BPBoostTaskExecutedEvent,
  BPClaimed as BPClaimedEvent,
  BPDeposited as BPDepositedEvent,
  BPFullyRaised as BPFullyRaisedEvent,
  BPRefunded as BPRefundedEvent,
  BPSettleUpdated as BPSettleUpdatedEvent,
  BPCanceled as BPCanceledEvent,
  ChromaticBP
} from '../generated/templates/ChromaticBP/ChromaticBP'

export function handleBPDeposited(event: BPDepositedEvent): void {
  let entity = new BPDeposited(event.transaction.hash.concatI32(event.logIndex.toI32()))
  entity.bp = event.address
  entity.provider = event.params.provider
  entity.amount = event.params.amount

  entity.blockNumber = event.block.number
  entity.blockTimestamp = event.block.timestamp
  entity.transactionHash = event.transaction.hash

  entity.save()

  let bpContract = ChromaticBP.bind(event.address)

  let raisedId = entity.bp.toHex() + '@' + event.block.number.toString()
  let raisedEntity = ChromaticBPTotalRaised.load(raisedId)
  if (raisedEntity == null) {
    raisedEntity = new ChromaticBPTotalRaised(raisedId)
    raisedEntity.bp = entity.bp
    raisedEntity.amount = bpContract.totalRaised()
    raisedEntity.blockNumber = event.block.number
    raisedEntity.blockTimestamp = event.block.timestamp
    raisedEntity.save()
  }

  let depositId =
    entity.bp.toHex() + '/' + entity.provider.toHex() + '@' + event.block.number.toString()
  let depositEntity = ChromaticBPDeposit.load(depositId)
  if (depositEntity == null) {
    depositEntity = new ChromaticBPDeposit(depositId)
    depositEntity.bp = entity.bp
    depositEntity.provider = entity.provider
    depositEntity.amount = bpContract.balanceOf(Address.fromBytes(entity.provider))
    depositEntity.blockNumber = event.block.number
    depositEntity.blockTimestamp = event.block.timestamp
    depositEntity.save()
  }
}

export function handleBPRefunded(event: BPRefundedEvent): void {
  let id =
    event.address.toHex() +
    '/' +
    event.params.provider.toHex() +
    '@' +
    event.block.number.toString()
  let entity = ChromaticBPRefund.load(id)
  if (entity == null) {
    entity = new ChromaticBPRefund(id)
    entity.bp = event.address
    entity.provider = event.params.provider
    entity.amount = event.params.amount
    entity.blockNumber = event.block.number
    entity.blockTimestamp = event.block.timestamp
    entity.save()
  }
}

export function handleBPClaimed(event: BPClaimedEvent): void {
  let id =
    event.address.toHex() +
    '/' +
    event.params.provider.toHex() +
    '@' +
    event.block.number.toString()
  let entity = ChromaticBPClaim.load(id)
  if (entity == null) {
    entity = new ChromaticBPClaim(id)
    entity.bp = event.address
    entity.provider = event.params.provider
    entity.bpTokenAmount = event.params.bpTokenAmount
    entity.lpTokenAmount = event.params.lpTokenAmount
    entity.blockNumber = event.block.number
    entity.blockTimestamp = event.block.timestamp
    entity.save()
  }
}

export function handleBPFullyRaised(event: BPFullyRaisedEvent): void {
  saveChromaticBPStatus(event)
}

export function handleBPBoostTaskCreated(event: BPBoostTaskCreatedEvent): void {
  saveChromaticBPStatus(event)
}

export function handleBPBoostTaskExecuted(event: BPBoostTaskExecutedEvent): void {
  let entity = new BPBoostTaskExecuted(event.transaction.hash.concatI32(event.logIndex.toI32()))
  entity.bp = event.address

  entity.blockNumber = event.block.number
  entity.blockTimestamp = event.block.timestamp
  entity.transactionHash = event.transaction.hash

  entity.save()

  saveChromaticBPStatus(event)
}

export function handleBPSettleUpdated(event: BPSettleUpdatedEvent): void {
  let entity = new BPSettleUpdated(event.transaction.hash.concatI32(event.logIndex.toI32()))
  entity.bp = event.address
  entity.totalLPToken = event.params.totalLPToken

  entity.blockNumber = event.block.number
  entity.blockTimestamp = event.block.timestamp
  entity.transactionHash = event.transaction.hash

  entity.save()

  saveChromaticBPStatus(event)
}

export function handleBPCanceled(event: BPCanceledEvent): void {
  let entity = new BPCanceled(event.transaction.hash.concatI32(event.logIndex.toI32()))
  entity.bp = event.address
  entity.blockNumber = event.block.number
  entity.blockTimestamp = event.block.timestamp
  entity.transactionHash = event.transaction.hash

  entity.save()

  saveChromaticBPStatus(event)
}

function saveChromaticBPStatus(event: ethereum.Event): void {
  let id = event.address.toHex() + '@' + event.block.number.toString()
  let entity = ChromaticBPStatus.load(id)
  if (entity == null) {
    let bpContract = ChromaticBP.bind(event.address)

    entity = new ChromaticBPStatus(id)
    entity.bp = bpContract._address
    entity.endTimeOfWarmup = bpContract.endTimeOfWarmup()
    entity.endTimeOfLockup = bpContract.endTimeOfLockup()
    entity.currentPeriod = bpContract.currentPeriod()
    entity.status = bpContract.status()
    entity.blockNumber = event.block.number
    entity.blockTimestamp = event.block.timestamp
    entity.save()
  }
}
