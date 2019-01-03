const chai = require('chai')
const assert = chai.assert
const BigNumber = web3.BigNumber
const should = chai.use(require('chai-bignumber')(BigNumber)).should()
const MerkluxCase = artifacts.require('MerkluxCase')

contract('MerkluxCase', async ([_, primary, alice, bob, attorney]) => {
  context('Dispatch transactions and seal two blocks on the child chain', async () => {
    it('should be able to deploy without out of gas', async () => {
      let merkluxCase = await MerkluxCase.new()
    })
  })
})
