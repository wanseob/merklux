const chai = require('chai')
const assert = chai.assert
const BigNumber = web3.BigNumber
const should = chai.use(require('chai-bignumber')(BigNumber)).should()
const { signMessage } = require('openzeppelin-solidity/test/helpers/sign')
const Merklux = artifacts.require('Merklux')
const MerkluxCase = artifacts.require('MerkluxCase')
const SampleReducer = artifacts.require('BalanceIncrease')
const { rlpEncode, STORE_KEY } = require('./utils')

contract('MerkluxCase', async ([_, primary, alice, bob, attorney]) => {
  context('Dispatch transactions and seal two blocks on the child chain', async () => {
    let originalRoot
    let targetRoot
    before(async () => {
      // deploy merklux on the child chain
      let merklux = await Merklux.new({ from: primary })
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
      let firstHashToSeal = await merklux.getBlockHashToSeal({ from: alice })
      let firstSignature = signMessage(alice, firstHashToSeal)
      await merklux.seal(firstSignature, { from: alice })
      await merklux.dispatch(STORE_KEY, 'increaseBalance', rlpEncode(VALUE_TO_INCREASE), { from: primary })
      await merklux.dispatch(STORE_KEY, 'increaseBalance', rlpEncode(VALUE_TO_INCREASE), { from: primary })
      await merklux.dispatch(STORE_KEY, 'increaseBalance', rlpEncode(VALUE_TO_INCREASE), { from: primary })
      let secondHashToSeal = await merklux.getBlockHashToSeal({ from: bob })
      let secondSignature = signMessage(bob, secondHashToSeal)
      await merklux.seal(secondSignature, { from: bob })
      originalRoot = {
        hash: firstHashToSeal,
        sig: firstSignature
      }
      targetRoot = {
        hash: secondHashToSeal,
        sig: secondSignature
      }
    })
    describe('constructor()', async () => {
      let merkluxCase
      it('should assign its original root and target root', async () => {
        merkluxCase = await MerkluxCase.new(
          originalRoot.hash,
          targetRoot.hash,
          bob,
          { from: alice }
        )
        assert.equal(await merkluxCase.accuser(), alice)
        assert.equal(await merkluxCase.defendant(), bob)
        assert.equal(await merkluxCase.original(), originalRoot.hash)
        assert.equal(await merkluxCase.target(), targetRoot.hash)
      })
    })
    context('Once a merklux case is deployed', async () => {
      beforeEach(async () => {
        merkluxCase = await MerkluxCase.new(
          originalRoot.hash,
          targetRoot.hash,
          bob,
          { from: alice }
        )
      })
      describe('appoint()', async () => {
        it('should assign a new EOA as an attorney for the case', async () => {
          await merkluxCase.appoint(attorney, { from: bob })
        })
        it('should be abled to called only by the defendant', async () => {
          try {
            await merkluxCase.appoint(attorney, { from: alice })
            assert.fail('Did not reverted')
          } catch (e) {
            assert.ok('Reverted successfully')
          }
        })
      })
      describe('commitOriginalBlock()', async () => {

      })
      describe('commitStoreData()', async () => {

      })
      describe('sealOriginalBlock()', async () => {

      })
      describe('commitDispatch()', async () => {

      })
      describe('sealDispatches()', async () => {

      })
      describe('dispatches()', async () => {

      })
      describe('status()', async () => {

      })
    })
  })
})
