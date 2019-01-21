const chai = require('chai')
const BigNumber = web3.BigNumber
chai.use(require('chai-bignumber')(BigNumber)).should()
const { Merklux } = require('../src/index')
const SampleReducer = artifacts.require('BalanceIncrease')

contract('MerkluxChain', async ([_, operator, user, sealer]) => {
  let merklux
  beforeEach('Use new chain for every test case', async () => {
    merklux = new Merklux(web3.currentProvider)
    await merklux.deployChain('V1')
  })
  describe('dispatch()', async () => {
    it('should deploy a new reducer with bytecode', async () => {
      await merklux.deployReducer('increaseBalance', SampleReducer.bytecode)
      let reducerKey = await merklux.get('&increaseBalance')
      reducerKey.should.equal(web3.utils.sha3(SampleReducer.bytecode))
    })
    it('should update value by dispatch', async () => {
      const VALUE_TO_INCREASE = 8
      await merklux.deployReducer('increaseBalance', SampleReducer.bytecode)
      await merklux.dispatch('increaseBalance', VALUE_TO_INCREASE, user)
      web3.utils.hexToNumber(await merklux.get(user)).should.equal(VALUE_TO_INCREASE)
      await merklux.dispatch('increaseBalance', VALUE_TO_INCREASE, user)
      web3.utils.hexToNumber(await merklux.get(user)).should.equal(VALUE_TO_INCREASE * 2)
      await merklux.dispatch('increaseBalance', VALUE_TO_INCREASE, user)
      web3.utils.hexToNumber(await merklux.get(user)).should.equal(VALUE_TO_INCREASE * 3)
    })
  })
  describe('seal()', async () => {
    it('should seal a block and increase chain height', async () => {
      await merklux.deployReducer('increaseBalance', SampleReducer.bytecode)
      const VALUE_TO_INCREASE = 8
      await merklux.dispatch('increaseBalance', VALUE_TO_INCREASE, user)
      await merklux.dispatch('increaseBalance', VALUE_TO_INCREASE, user)
      await merklux.dispatch('increaseBalance', VALUE_TO_INCREASE, user)
      await merklux.seal(sealer)
    })
  })
})
