const chai = require('chai')
const BigNumber = web3.BigNumber
chai.use(require('chai-bignumber')(BigNumber)).should()
const MerkluxChain = artifacts.require('MerkluxChain')
const MerkluxFactory = artifacts.require('MerkluxFactory')
const MerkluxStore = artifacts.require('MerkluxStore')
const SampleReducer = artifacts.require('BalanceIncrease')
const { rlpEncode } = require('./utils')

contract('MerkluxChain', async ([_, operator, user, sealer]) => {
  let merkluxChain
  let merkluxStore
  beforeEach('Use new chain for every test case', async () => {
    let deployed = await initiateChain(operator)
    merkluxChain = await MerkluxChain.at(deployed.chain)
    merkluxStore = await MerkluxStore.at(deployed.store)
  })
  describe('dispatch()', async () => {
    it('should deploy a new reducer with bytecode', async () => {
      await deployReducer(merkluxChain, SampleReducer.bytecode, operator)
      let reducerKey = await merkluxStore.get(web3.utils.stringToHex('&increaseBalance'))
      reducerKey.should.equal(web3.utils.sha3(SampleReducer.bytecode))
    })
    it('should update value by dispatch', async () => {
      await deployReducer(merkluxChain, SampleReducer.bytecode, operator)
      const VALUE_TO_INCREASE = 8
      await increaseBalance(merkluxChain, VALUE_TO_INCREASE, operator, user)
      web3.utils.hexToNumber(await merkluxStore.get(user)).should.equal(VALUE_TO_INCREASE)
      await increaseBalance(merkluxChain, VALUE_TO_INCREASE, operator, user)
      web3.utils.hexToNumber(await merkluxStore.get(user)).should.equal(VALUE_TO_INCREASE * 2)
      await increaseBalance(merkluxChain, VALUE_TO_INCREASE, operator, user)
      web3.utils.hexToNumber(await merkluxStore.get(user)).should.equal(VALUE_TO_INCREASE * 3)
    })
  })
  describe('seal()', async () => {
    it('should seal a block and increase chain height', async () => {
      await deployReducer(merkluxChain, SampleReducer.bytecode, operator)
      const VALUE_TO_INCREASE = 8
      await increaseBalance(merkluxChain, VALUE_TO_INCREASE, operator, user)
      await increaseBalance(merkluxChain, VALUE_TO_INCREASE, operator, user)
      await increaseBalance(merkluxChain, VALUE_TO_INCREASE, operator, user)
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
      await sealBlock(merkluxChain, sealer)
    })
  })
})

let initiateChain = async (operator) => {
  let factory = await MerkluxFactory.new(
    'V1',
    web3.utils.sha3(MerkluxChain.bytecode),
    web3.utils.sha3(MerkluxStore.bytecode)
  )
  await factory.createApp('BalanceIncreaser', { from: operator })
  await factory.deployChain('BalanceIncreaser', MerkluxChain.bytecode, { from: operator })
  await factory.deployStore('BalanceIncreaser', MerkluxStore.bytecode, { from: operator })
  await factory.complete('BalanceIncreaser', { from: operator })
  let { chain, store } = await factory.getMerklux('BalanceIncreaser')
  return { chain, store }
}
let deployReducer = async (chain, bytecode, operator) => {
  let { actionHash, prevBlockHash, nonce } = await chain.makeAction(
    'increaseBalance',
    bytecode,
    true,
    { from: operator }
  )
  let signature = await web3.eth.sign(actionHash, operator)
  await chain.dispatch(
    'increaseBalance',
    bytecode,
    prevBlockHash,
    nonce.toNumber(),
    true,
    signature,
    { from: operator }
  )
}

let increaseBalance = async (chain, increment, operator, user) => {
  let { actionHash, prevBlockHash, nonce } = await chain.makeAction(
    'increaseBalance',
    rlpEncode(increment),
    false,
    { from: user }
  )
  let signature = await web3.eth.sign(actionHash, user)
  await chain.dispatch(
    'increaseBalance',
    rlpEncode(increment),
    prevBlockHash,
    nonce.toNumber(),
    false,
    signature,
    { from: operator }
  )
}

let sealBlock = async (chain, sealer) => {
  let hashToSeal = await chain.getBlockHashToSeal({ from: sealer })
  const signature = await web3.eth.sign(hashToSeal, sealer)
  await chain.seal(signature, { from: sealer })
  return hashToSeal
}
