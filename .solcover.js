module.exports = {
  compileCommand: 'node --max-old-space-size=4096 ../node_modules/.bin/truffle compile',
  testCommand: 'node --max-old-space-size=4096 ../node_modules/.bin/truffle test --network coverage',
  'norpc': true,
  'copyPackages': [
    'openzeppelin-solidity',
    'solidity-partial-tree',
    'solidity-patricia-tree',
    'solidity-rlp'
  ],
  skipFiles: [
    'libs'
  ]
}
