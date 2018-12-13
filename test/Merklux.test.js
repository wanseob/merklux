const chai = require('chai')
const assert = chai.assert
const BigNumber = web3.BigNumber
const should = chai.use(require('chai-bignumber')(BigNumber)).should()
const Merklux = artifacts.require('Merklux')
const MerkluxStore = artifacts.require('MerkluxStore')
const SampleReducer = artifacts.require('BalanceIncrease')
const { signMessage } = require('openzeppelin-solidity/test/helpers/sign')
const { rlpEncode, STORE_KEY } = require('./utils')

contract('Merklux', async ([_, primary, nonPrimary]) => {
  let merklux
  describe('newStore()', async () => {
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
      it('is only able to be called by the primary address', async () => {
        try {
          await merklux.setReducer(STORE_KEY, 'increaseBalance', SampleReducer.bytecode, { from: nonPrimary })
          assert.fail('non primary account was able to execute this function')
        } catch (e) {
          assert.ok('successfully reverted')
        }
      })
      it('should deploy a new reducer with bytecode', async () => {
        await merklux.setReducer(STORE_KEY, 'increaseBalance', SampleReducer.bytecode, { from: primary })
      })
    })
  })
  describe('dispatch()', async () => {
    context('when a store & reducer is deployed successfully', async () => {
      before(async () => {
        // deploy merklux on the child chain
        merklux = await Merklux.new({ from: primary })
        // register new store
        await merklux.newStore(STORE_KEY, { from: primary })
        // register new reducer
        await merklux.setReducer(STORE_KEY, 'increaseBalance', SampleReducer.bytecode, { from: primary })
      })
      it('should update its value by the reducer information', async () => {
        const VALUE_TO_INCREASE = 8
        let userBalance = await merklux.get(STORE_KEY, primary)
        // empty
        assert.equal(userBalance.toString(), '0x')
        await merklux.dispatch(STORE_KEY, 'increaseBalance', rlpEncode(VALUE_TO_INCREASE), { from: primary })
        userBalance = await merklux.get(STORE_KEY, primary)
        assert.equal(web3.toDecimal(userBalance), VALUE_TO_INCREASE)
        await merklux.dispatch(STORE_KEY, 'increaseBalance', rlpEncode(VALUE_TO_INCREASE), { from: primary })
        userBalance = await merklux.get(STORE_KEY, primary)
        assert.equal(web3.toDecimal(userBalance), VALUE_TO_INCREASE * 2)
        await merklux.dispatch(STORE_KEY, 'increaseBalance', rlpEncode(VALUE_TO_INCREASE), { from: primary })
        userBalance = await merklux.get(STORE_KEY, primary)
        assert.equal(web3.toDecimal(userBalance), VALUE_TO_INCREASE * 3)
      })
    })
  })

  describe('getBlockHashToSeal()', async () => {
    before(async () => {
      // deploy merklux on the child chain
      merklux = await Merklux.new({ from: primary })
      // register new store
      await merklux.newStore(STORE_KEY, { from: primary })
      // register new reducer
      await merklux.setReducer(STORE_KEY, 'increaseBalance', SampleReducer.bytecode, { from: primary })
      // dispatch 3 times
      const VALUE_TO_INCREASE = 8
      await merklux.dispatch(STORE_KEY, 'increaseBalance', rlpEncode(VALUE_TO_INCREASE), { from: primary })
      await merklux.dispatch(STORE_KEY, 'increaseBalance', rlpEncode(VALUE_TO_INCREASE), { from: primary })
      await merklux.dispatch(STORE_KEY, 'increaseBalance', rlpEncode(VALUE_TO_INCREASE), { from: primary })
    })
    it('should return bytes32 type of hash value to seal', async () => {
      let hashToSeal = await merklux.getBlockHashToSeal()
      assert.ok(isHash(hashToSeal))
    })
  })
  describe('seal()', async () => {
    let hashToSeal
    before(async () => {
      // deploy merklux on the child chain
      merklux = await Merklux.new({ from: primary })
      // register new store
      await merklux.newStore(STORE_KEY, { from: primary })
      // register new reducer
      await merklux.setReducer(STORE_KEY, 'increaseBalance', SampleReducer.bytecode, { from: primary })
      // dispatch 3 times
      const VALUE_TO_INCREASE = 8
      await merklux.dispatch(STORE_KEY, 'increaseBalance', rlpEncode(VALUE_TO_INCREASE), { from: primary })
      await merklux.dispatch(STORE_KEY, 'increaseBalance', rlpEncode(VALUE_TO_INCREASE), { from: primary })
      await merklux.dispatch(STORE_KEY, 'increaseBalance', rlpEncode(VALUE_TO_INCREASE), { from: primary })
      // Get hash to seal
      hashToSeal = await merklux.getBlockHashToSeal({ from: primary })
    })
    it('should be called by the snapshotSubmitter()', async () => {
      // Sign
      const signature = signMessage(primary, hashToSeal)
      // Seal
      try {
        await merklux.seal(signature, { from: primary })
        assert.ok('Sealed successfully')
      } catch (e) {
        assert.fail('Failed to seal a block')
      }
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
