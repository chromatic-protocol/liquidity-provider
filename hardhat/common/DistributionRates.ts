export function getLinearDistributionConfig(
  startLevel: number,
  endLevel: number,
  halfBinCount = 36
): {
  distributionRates: number[]
  utilizationTargetBPS: number
} {
  console.assert(startLevel >= 0 && startLevel <= 100, 'check startLevel range')
  console.assert(endLevel >= 0 && endLevel <= 100, 'check endLevel range')
  let utilizationTargetBPS =
    100 * (Math.abs(startLevel - endLevel) / 2.0 + Math.min(startLevel, endLevel))
  console.assert(
    utilizationTargetBPS > 0 && utilizationTargetBPS < 10000,
    `utilizationTargetBPS ${utilizationTargetBPS} outof range`
  )

  const SCALE = 100
  let dist = linspace(startLevel * SCALE, endLevel * SCALE, halfBinCount)
  dist = dist.map((x) => Math.ceil(x / 2))
  let distributionRates = [...[...dist].reverse(), ...dist]
  return {
    distributionRates,
    utilizationTargetBPS
  }
}

function linspace(start: number, stop: number, num: number) {
  let div = num + 2
  const step = (stop - start) / div
  return Array.from({ length: num }, (_, i) => start + step * (i + 1))
}
