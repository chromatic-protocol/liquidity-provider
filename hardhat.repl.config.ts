import util from 'util'
import config from './hardhat.config'
import './hardhat/repl'
const MNEMONIC_JUNK = 'test test test test test test test test test test test junk'

console.log('hc', util.inspect(config, { depth: 5 }))
export default config
