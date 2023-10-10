import {
  assert,
  describe,
  test,
  clearStore,
  beforeAll,
  afterAll
} from "matchstick-as/assembly/index"
import { Address } from "@graphprotocol/graph-ts"
import { ChromaticLPRegistered } from "../generated/schema"
import { ChromaticLPRegistered as ChromaticLPRegisteredEvent } from "../generated/ChromaticLPRegistry/ChromaticLPRegistry"
import { handleChromaticLPRegistered } from "../src/chromatic-lp-registry"
import { createChromaticLPRegisteredEvent } from "./chromatic-lp-registry-utils"

// Tests structure (matchstick-as >=0.5.0)
// https://thegraph.com/docs/en/developer/matchstick/#tests-structure-0-5-0

describe("Describe entity assertions", () => {
  beforeAll(() => {
    let lp = Address.fromString("0x0000000000000000000000000000000000000001")
    let newChromaticLPRegisteredEvent = createChromaticLPRegisteredEvent(lp)
    handleChromaticLPRegistered(newChromaticLPRegisteredEvent)
  })

  afterAll(() => {
    clearStore()
  })

  // For more test scenarios, see:
  // https://thegraph.com/docs/en/developer/matchstick/#write-a-unit-test

  test("ChromaticLPRegistered created and stored", () => {
    assert.entityCount("ChromaticLPRegistered", 1)

    // 0xa16081f360e3847006db660bae1c6d1b2e17ec2a is the default address used in newMockEvent() function
    assert.fieldEquals(
      "ChromaticLPRegistered",
      "0xa16081f360e3847006db660bae1c6d1b2e17ec2a-1",
      "lp",
      "0x0000000000000000000000000000000000000001"
    )

    // More assert options:
    // https://thegraph.com/docs/en/developer/matchstick/#asserts
  })
})
