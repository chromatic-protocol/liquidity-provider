import { newMockEvent } from "matchstick-as"
import { ethereum, Address } from "@graphprotocol/graph-ts"
import {
  ChromaticLPRegistered,
  ChromaticLPUnregistered,
  OwnershipTransferred
} from "../generated/ChromaticLPRegistry/ChromaticLPRegistry"

export function createChromaticLPRegisteredEvent(
  lp: Address
): ChromaticLPRegistered {
  let chromaticLpRegisteredEvent = changetype<ChromaticLPRegistered>(
    newMockEvent()
  )

  chromaticLpRegisteredEvent.parameters = new Array()

  chromaticLpRegisteredEvent.parameters.push(
    new ethereum.EventParam("lp", ethereum.Value.fromAddress(lp))
  )

  return chromaticLpRegisteredEvent
}

export function createChromaticLPUnregisteredEvent(
  lp: Address
): ChromaticLPUnregistered {
  let chromaticLpUnregisteredEvent = changetype<ChromaticLPUnregistered>(
    newMockEvent()
  )

  chromaticLpUnregisteredEvent.parameters = new Array()

  chromaticLpUnregisteredEvent.parameters.push(
    new ethereum.EventParam("lp", ethereum.Value.fromAddress(lp))
  )

  return chromaticLpUnregisteredEvent
}

export function createOwnershipTransferredEvent(
  previousOwner: Address,
  newOwner: Address
): OwnershipTransferred {
  let ownershipTransferredEvent = changetype<OwnershipTransferred>(
    newMockEvent()
  )

  ownershipTransferredEvent.parameters = new Array()

  ownershipTransferredEvent.parameters.push(
    new ethereum.EventParam(
      "previousOwner",
      ethereum.Value.fromAddress(previousOwner)
    )
  )
  ownershipTransferredEvent.parameters.push(
    new ethereum.EventParam("newOwner", ethereum.Value.fromAddress(newOwner))
  )

  return ownershipTransferredEvent
}
