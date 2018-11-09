const chai = require('chai')
const assert = chai.assert
const BigNumber = web3.BigNumber
const should = chai.use(require('chai-bignumber')(BigNumber)).should()
const Merklux = artifacts.require('Merklux')
const MerkluxStore = artifacts.require('MerkluxStore')
const SampleReducer = artifacts.require('BalanceIncrease')
const rlp = require('rlp')

const ZERO = '0x0000000000000000000000000000000000000000000000000000000000000000'
const STORE_KEY = web3.sha3('default', { encoding: 'hex' })
const rlpEncode = (data) => '0x' + rlp.encode(data).toString('hex')

contract('Merklux', async ([_, primary, nonPrimary]) => {
  let merklux
  describe('newStore', async () => {
    before(async () => {
      merklux = await Merklux.new({ from: primary })
    })
    it('is only able to be called by the primary address', async () => {
      await merklux.newStore(STORE_KEY, { from: primary })
      assert.ok('executed successfully')
      try {
        await merklux.newStore(STORE_KEY, { from: nonPrimary })
        assert.fail('Non primary account was able to execute the newStore() function')
      } catch (e) {
        assert.ok('reverted successfully')
      }
    })
  })
  describe('setReducer', async () => {
    context('When a new store is set', async () => {
      before(async () => {
        merklux = await Merklux.new({ from: primary })
        await merklux.newStore(STORE_KEY, { from: primary })
      })
      it('should deploy a new reducer with code', async () => {
        await merklux.setReducer(
          STORE_KEY,
          'increaseBalance',
          10,
          { from: primary }
        )
      })
      it('is only able to be called by the primary address', async () => {
        try {
          await merklux.setReducer(
            web3.sha3('default', { encoding: 'hex' }),
            'increaseBalance',
            SampleReducer.bytecode,
            { from: nonPrimary }
          )
          assert.fail('non primary account was able to execute this function')
        } catch (e) {
          assert.ok('successfully reverted')
        }
      })
    })
  })
  describe('dispatch()', async () => {
    context('when a store & reducer is deployed', async () => {
      before(async () => {
        merklux = await Merklux.new({ from: primary })
        await merklux.newStore(web3.sha3('default', { encoding: 'hex' }), { from: primary })
        await merklux.setReducer(
          web3.sha3('default', { encoding: 'hex' }),
          'increaseBalance',
          SampleReducer.bytecode,
          { from: primary }
        )
      })
      it('should update its value by the reducer information', async () => {
        const VALUE_TO_INCREASE = 8
        await merklux.dispatch(STORE_KEY, 'increaseBalance', rlpEncode(VALUE_TO_INCREASE), { from: primary })
        let updatedValue = await merklux.get(STORE_KEY, primary)
        assert.equal(web3.toDecimal(updatedValue), VALUE_TO_INCREASE)
      })
    })
  })
})