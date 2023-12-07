export function getLinearDistributionConfig(
  startLevel: number,
  endLevel: number,
  halfBinCount = 36,
  isLongShort = 0 // 0 for longAndShort, -1 for short only, 1 for long only
): {
  distributionRates: number[]
} {
  console.assert(startLevel >= 0 && startLevel <= 100, 'check startLevel range')
  console.assert(endLevel >= 0 && endLevel <= 100, 'check endLevel range')

  const SCALE = 100
  let dist = linspace(startLevel * SCALE, endLevel * SCALE, halfBinCount)

  let distributionRates
  if (isLongShort === 0) {
    dist = dist.map((x) => Math.ceil(x / 2))
    distributionRates = [...[...dist].reverse(), ...dist]
  } else if (isLongShort === 1) {
    distributionRates = [...dist]
  } else if (isLongShort === -1) {
    distributionRates = [...[...dist].reverse()]
  } else {
    throw new Error('unexpected value of isLongShort')
  }
  return {
    distributionRates
  }
}

function linspace(start: number, stop: number, num: number): number[] {
  let div = num + 2
  const step = (stop - start) / div
  return Array.from({ length: num }, (_, i) => start + step * (i + 1))
}

function sqrtspace(start: number, stop: number, num: number): number[] {
  const diff = stop - start
  return Array.from({ length: num }, (_, i) => start + diff * Math.sqrt((i + 1) / (num + 2)))
}

export function getSqrtDistributionConfig(
  startLevel: number,
  endLevel: number,
  halfBinCount = 36,
  isLongShort = 0 // 0 for longAndShort, -1 for short only, 1 for long only
): {
  distributionRates: number[]
} {
  const SCALE = 100
  let dist = sqrtspace(startLevel * SCALE, endLevel * SCALE, halfBinCount)
  dist = dist.map((x) => Math.ceil(x / 2))

  let distributionRates
  if (isLongShort === 0) {
    dist = dist.map((x) => Math.ceil(x / 2))
    distributionRates = [...[...dist].reverse(), ...dist]
  } else if (isLongShort === 1) {
    distributionRates = [...dist]
  } else if (isLongShort === -1) {
    distributionRates = [...[...dist].reverse()]
  } else {
    throw new Error('unexpected value of isLongShort')
  }
  return {
    distributionRates
  }
}
