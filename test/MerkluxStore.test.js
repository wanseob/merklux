const chai = require('chai')
const assert = chai.assert
const BigNumber = web3.BigNumber
const should = chai.use(require('chai-bignumber')(BigNumber)).should()

const MerkluxStore = artifacts.require('MerkluxStore')
const { toNodeObject, progress } = require('./utils')

const ZERO = '0x0000000000000000000000000000000000000000000000000000000000000000'

contract('MerkluxStore', async ([_, primary, nonPrimary]) => {

})
