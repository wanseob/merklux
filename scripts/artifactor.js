const fs = require('fs')
const SOL_PATH = './build/contracts'
const OUTPUT = './src/compiled.js'
const contracts = fs.readdirSync(SOL_PATH)
console.log(contracts)

let compiled = {}
for (let contract of contracts) {
  let obj = JSON.parse(fs.readFileSync(`${SOL_PATH}/${contract}`, 'utf8'))
  compiled[contract.slice(0, -5)] = {
    contractName: obj.contractName,
    abi: obj.abi,
    bytecode: obj.bytecode,
    deployedBytecode: obj.deployedBytecode,
    sourceMap: obj.sourceMap,
    deployedSourceMap: obj.deployedSourceMap,
    source: obj.source
  }
}

const compiledJS = `
module.exports = {
  contracts: ${JSON.stringify(compiled)}
}
`
fs.writeFile(OUTPUT, compiledJS, function (err) {
  if (err) {
    return console.log(err)
  }
  console.log('ABIs and bytecode were saved')
})
