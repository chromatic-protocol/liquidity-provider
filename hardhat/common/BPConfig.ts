import type { BPConfig, AddressType } from './types'
import { getAutomateAddress } from 
export function getBPConfig({
  lp,
  minRaisingTarget,
  maxRaisingTarget,
  startTimeOfWarmup,
  durationOfWarmup,
  durationOfLockup
}: {
    lp: AddressType
    minRaisingTarget: bigint
    maxRaisingTarget: bigint
    startTimeOfWarmup: number
    durationOfWarmup: number
    durationOfLockup: number
    }): BPConfig {
    
    
    
  }
