const chai = require('chai')
const assert = chai.assert
const BigNumber = web3.BigNumber
const should = chai.use(require('chai-bignumber')(BigNumber)).should()
const MerkluxChain = artifacts.require('MerkluxChain')
const MerkluxVM = artifacts.require('MerkluxVM')
const MerkluxStore = artifacts.require('MerkluxStore')
const SampleReducer = artifacts.require('BalanceIncrease')
const { signMessage } = require('openzeppelin-solidity/test/helpers/sign')
const { rlpEncode } = require('./utils')

contract('MerkluxChain', async ([_, primary, nonPrimary]) => {
  let merkluxChain
  describe('dispatch() - set reducer', async () => {
    it('should deploy a new reducer', async () => {
      merkluxChain = await MerkluxChain.new({ from: primary })
      let [txHash, prevBlockHash, nonce] = await merkluxChain.makeTx(
        'increaseBalance',
        SampleReducer.bytecode,
        true,
        { from: primary }
      )
      let signature = signMessage(primary, txHash)
      await merkluxChain.dispatch(
        'increaseBalance',
        SampleReducer.bytecode,
        prevBlockHash,
        nonce.toNumber(),
        true,
        signature,
        { from: primary }
      )
      let reducerKey = await merkluxChain.get('&increaseBalance')
      console.log(reducerKey)
    })
    it('should update value by dispatch', async () => {
      const VALUE_TO_INCREASE = 8
      let [txHash, prevBlockHash, nonce] = await merkluxChain.makeTx(
        'increaseBalance',
        rlpEncode(VALUE_TO_INCREASE),
        false,
        { from: primary }
      )
      let signature = signMessage(primary, txHash)
      await merkluxChain.dispatch(
        'increaseBalance',
        rlpEncode(VALUE_TO_INCREASE),
        prevBlockHash,
        nonce.toNumber(),
        false,
        signature,
        { from: primary }
      )
      let val = await merkluxChain.get(primary)
      console.log(val)
    })
  })
})

const isHash = (hash) => {
  try {
    web3.toDecimal(hash)
  } catch (e) {
    return false
  }
  if (!hash.startsWith('0x')) {
    return false
  }
  if (hash.length != 66) {
    return false
  }
  return true
}
