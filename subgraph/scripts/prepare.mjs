import fs from 'fs'
import Mustache from 'mustache'

import { join } from 'path'

const abiPath = join('.', 'abis')
const deployments = join('..', '..', 'deployments')

async function loadDeployment(network, contract) {
  const json = await import(join(deployments, network, `${contract}.json`), {
    assert: { type: 'json' }
  })
  return json.default
}

function saveABI(contract, deployment) {
  if (!fs.existsSync(abiPath)) fs.mkdirSync(abiPath, { recursive: true })
  fs.writeFileSync(join(abiPath, `${contract}.json`), JSON.stringify(deployment.abi, null, 2))
}

async function loadABIFromArtifacts(interfaceName, path) {
  const interfacesPath = join(...'../../artifacts'.split('/'), ...path.split('/'))
  const json = await import(join(interfacesPath, `${interfaceName}.sol`, `${interfaceName}.json`), {
    assert: { type: 'json' }
  })
  return json.default
}

async function saveABIFromArtifacts(interfaceName, path) {
  if (!fs.existsSync(abiPath)) fs.mkdirSync(abiPath, { recursive: true })
  const json = await loadABIFromArtifacts(interfaceName, path)

  fs.writeFileSync(join(abiPath, `${interfaceName}.json`), JSON.stringify(json.abi, null, 2))
}

async function main() {
  const network = process.argv[2]
  const templateFile = process.argv[3]
  const outputFile = process.argv[4]

  await saveABIFromArtifacts('IERC20Metadata', '@openzeppelin/contracts/token/ERC20/extensions')
  await saveABIFromArtifacts('IChromaticMarket', '@chromatic-protocol/contracts/core/interfaces')
  await saveABIFromArtifacts('IOracleProvider', '@chromatic-protocol/contracts/oracle/interfaces')

  const lpRegistry = await loadDeployment(network, 'ChromaticLPRegistry')
  saveABI('ChromaticLPRegistry', lpRegistry)
  await saveABIFromArtifacts('ChromaticLP', 'contracts/lp')

  const bpFactory = await loadDeployment(network, 'ChromaticBPFactory')
  saveABI('ChromaticBPFactory', bpFactory)
  await saveABIFromArtifacts('ChromaticBP', 'contracts/bp')

  const template = fs.readFileSync(templateFile).toString()
  const output = Mustache.render(template, {
    network: network === 'mantle_testnet' ? 'testnet' : network,
    lpBlocknumber: lpRegistry.receipt.blockNumber,
    bpBlocknumber: bpFactory.receipt.blockNumber,
    ChromaticLPRegistry: lpRegistry.address,
    ChromaticBPFactory: bpFactory.address
  })
  fs.writeFileSync(outputFile, output)

  console.log('✅  Prepared', outputFile)
}
main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error)
    process.exit(1)
  })
