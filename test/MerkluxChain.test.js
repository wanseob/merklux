const chai = require('chai')
const assert = chai.assert
const BigNumber = web3.BigNumber
const should = chai.use(require('chai-bignumber')(BigNumber)).should()
const MerkluxChain = artifacts.require('MerkluxChain')
const MerkluxFactory = artifacts.require('MerkluxFactory')
const MerkluxStore = artifacts.require('MerkluxStore')
const SampleReducer = artifacts.require('BalanceIncrease')
const { rlpEncode } = require('./utils')

contract('MerkluxChain', async ([_, primary, nonPrimary]) => {
  let initiateChain = async () => {
    let factory = await MerkluxFactory.new(
      'V1',
      web3.utils.sha3(MerkluxChain.bytecode),
      web3.utils.sha3(MerkluxStore.bytecode)
    )
    await factory.createApp('BalanceIncreaser', { from: primary })
    await factory.deployChain('BalanceIncreaser', MerkluxChain.bytecode, { from: primary })
    await factory.deployStore('BalanceIncreaser', MerkluxStore.bytecode, { from: primary })
    await factory.complete('BalanceIncreaser', { from: primary })
    let { chain, store } = await factory.getMerklux('BalanceIncreaser')
    return { chain, store }
  }

  let deployReducer = async (chain, bytecode) => {
    let { actionHash, prevBlockHash, nonce } = await chain.makeAction(
      'increaseBalance',
      bytecode,
      true,
      { from: primary }
    )
    let signature = await web3.eth.sign(actionHash, primary)
    await chain.dispatch(
      'increaseBalance',
      bytecode,
      prevBlockHash,
      nonce.toNumber(),
      true,
      signature,
      { from: primary }
    )
  }

  let increaseBalance = async (chain, increment) => {
    let { actionHash, prevBlockHash, nonce } = await chain.makeAction(
      'increaseBalance',
      rlpEncode(increment),
      false,
      { from: primary }
    )
    let signature = await web3.eth.sign(actionHash, primary)
    let result = await chain.dispatch(
      'increaseBalance',
      rlpEncode(increment),
      prevBlockHash,
      nonce.toNumber(),
      false,
      signature,
      { from: primary }
    )
  }

  let merkluxChain
  let merkluxStore
  beforeEach('Use new chain for every test case', async () => {
    let deployed = await initiateChain()
    merkluxChain = await MerkluxChain.at(deployed.chain)
    merkluxStore = await MerkluxStore.at(deployed.store)
  })
  describe('dispatch()', async () => {
    it('should deploy a new reducer with bytecode', async () => {
      await deployReducer(merkluxChain, SampleReducer.bytecode)
      let reducerKey = await merkluxStore.get(web3.utils.stringToHex('&increaseBalance'))
      reducerKey.should.equal(web3.utils.sha3(SampleReducer.bytecode))
    })
    it('should update value by dispatch', async () => {
      await deployReducer(merkluxChain, SampleReducer.bytecode)
      const VALUE_TO_INCREASE = 8
      await increaseBalance(merkluxChain, VALUE_TO_INCREASE)
      web3.utils.hexToNumber(await merkluxStore.get(primary)).should.equal(VALUE_TO_INCREASE)
      await increaseBalance(merkluxChain, VALUE_TO_INCREASE)
      web3.utils.hexToNumber(await merkluxStore.get(primary)).should.equal(VALUE_TO_INCREASE * 2)
      await increaseBalance(merkluxChain, VALUE_TO_INCREASE)
      web3.utils.hexToNumber(await merkluxStore.get(primary)).should.equal(VALUE_TO_INCREASE * 3)
      let actionNum = await merkluxStore.getActionNum()
      let state = await merkluxStore.getStateRoot()
      let reference = await merkluxStore.getReferenceRoot()
      let action = await merkluxStore.getActionRoot()
      console.log(actionNum.toNumber(), state, reference, action)
    })
  })
  describe('seal()', async () => {
    let hashToSeal
    it('should seal a block and increase chain height', async () => {
      await deployReducer(merkluxChain, SampleReducer.bytecode)
      const VALUE_TO_INCREASE = 8
      await increaseBalance(merkluxChain, VALUE_TO_INCREASE)
      await increaseBalance(merkluxChain, VALUE_TO_INCREASE)
      await increaseBalance(merkluxChain, VALUE_TO_INCREASE)
      let references = []
      while (true) {
        try {
          references.push(await merkluxStore.references.call(references.length))
        } catch (e) {
          break
        }
      }
      let actions = []
      while (true) {
        try {
          actions.push(await merkluxStore.actions.call(actions.length))
        } catch (e) {
          break
        }
      }
      console.log('referred values', references)
      console.log('action values', actions)
      // Get hash to seal
      hashToSeal = await merkluxChain.getBlockHashToSeal({ from: primary })
      let actionNum = await merkluxStore.getActionNum()
      let state = await merkluxStore.getStateRoot()
      let reference = await merkluxStore.getReferenceRoot()
      let action = await merkluxStore.getActionRoot()
      console.log(actionNum.toNumber(), state, reference, action)
      console.log('hash to seal', hashToSeal)
      // Sign
      const signature = await web3.eth.sign(hashToSeal, primary)
      console.log('signature', signature)
      // Seal
      await merkluxChain.seal(signature, { from: primary })
    })
  })
})

