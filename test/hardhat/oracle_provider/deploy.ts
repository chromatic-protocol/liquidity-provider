import { OracleProviderMock } from '~/typechain-types'
import { deployContract } from '../utils'

export async function deploy(): Promise<OracleProviderMock> {
  return await deployContract<OracleProviderMock>('OracleProviderMock')
}
