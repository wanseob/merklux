const chai = require('chai')
const assert = chai.assert
const BigNumber = web3.BigNumber
const should = chai.use(require('chai-bignumber')(BigNumber)).should()
const MerkluxReducer = artifacts.require('MerkluxReducer')
const MerkluxTree = artifacts.require('MerkluxTree')
const BalanceIncrease = artifacts.require('BalanceIncrease')
const rlp = require('rlp')

const ZERO = '0x0000000000000000000000000000000000000000000000000000000000000000'

const rlpEncode = (param) => {
  return '0x' + rlp.encode(param).toString('hex')
}
contract('MerkluxReducer', async ([_, primary, nonPrimary]) => {
  it('should update balance correctly', async () => {
    let tree = await MerkluxTree.new({ from: primary })
    let reducer = await BalanceIncrease.new()
    await tree.insert(rlpEncode(primary), rlpEncode(10), { from: primary })
    let balance = await tree.get(rlpEncode(primary))
    let result = await reducer.reduce(tree.address, primary, rlpEncode(30))
    assert.equal('0x' + rlp.decode(result[0])[0].toString('hex'), primary)
    assert.equal('0x' + rlp.decode(result[1])[0].toString('hex'), web3.toHex(40))
  })
})