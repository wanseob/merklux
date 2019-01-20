const { contracts } = require('./compiled')
const contract = require('truffle-contract')
const Web3 = require('web3')
const rlp = require('rlp')
const rlpEncode = data => '0x' + rlp.encode(data).toString('hex')

class Merklux {
  constructor (web3Provider) {
    this.web3 = new Web3(web3Provider)
    this.MerkluxFactory = contract(contracts.MerkluxFactory)
    this.MerkluxStore = contract(contracts.MerkluxStore)
    this.MerkluxChain = contract(contracts.MerkluxChain)
    this.MerkluxFactory.setProvider(web3Provider)
    this.MerkluxStore.setProvider(web3Provider)
    this.MerkluxChain.setProvider(web3Provider)
  }

  /**
   *
   * @param appName Your application name as a string
   * @param deployer Address of the deployer. Web3 provider should have the private key access for the given address.
   * @returns {Promise<{chain: *, store: *}>}
   */
  async deployChain (appName, deployer = undefined) {
    if (deployer === undefined) {
      deployer = (await this.web3.eth.getAccounts())[0]
    }
    this.factory = await this.MerkluxFactory.new(
      appName,
      this.web3.utils.sha3(this.MerkluxChain.bytecode),
      this.web3.utils.sha3(this.MerkluxStore.bytecode),
      { from: deployer }
    )
    await this.factory.createApp(appName, { from: deployer })
    await this.factory.deployChain(appName, this.MerkluxChain.bytecode, {
      from: deployer
    })
    await this.factory.deployStore(appName, this.MerkluxStore.bytecode, {
      from: deployer
    })
    await this.factory.complete(appName, { from: deployer })
    const { chain, store } = await this.factory.getMerklux(appName, { from: deployer })
    await this.setChain(chain)
    await this.setStore(store)
    return { chain, store }
  }

  async setChain (address) {
    this.chain = await this.MerkluxChain.at(address)
  }

  async setStore (address) {
    this.store = await this.MerkluxStore.at(address)
  }

  async deployReducer (actionName, bytecode, operator = undefined) {
    if (operator === undefined) {
      operator = (await this.web3.eth.getAccounts())[0]
    }
    let { actionHash, prevBlockHash, nonce } = await this.chain.makeAction(
      actionName,
      bytecode,
      true,
      { from: operator }
    )
    let signature = await this.web3.eth.sign(actionHash, operator)
    await this.chain.dispatch(
      actionName,
      bytecode,
      prevBlockHash,
      nonce.toNumber(),
      true,
      signature,
      { from: operator }
    )
  }

  async dispatch (actionName, params, user = undefined) {
    if (user === undefined) {
      user = (await this.web3.eth.getAccounts())[0]
    }
    let { actionHash, prevBlockHash, nonce } = await this.chain.makeAction(
      actionName,
      rlpEncode(params),
      false,
      { from: user }
    )
    let signature = await this.web3.eth.sign(actionHash, user)
    let result = await this.chain.dispatch(
      actionName,
      rlpEncode(params),
      prevBlockHash,
      nonce.toNumber(),
      false,
      signature,
      { from: user }
    )
    return result
  }

  async seal (sealer = undefined) {
    if (sealer === undefined) {
      sealer = (await this.web3.eth.getAccounts())[0]
    }
    let hashToSeal = await this.chain.getBlockHashToSeal({ from: sealer })
    const signature = await this.web3.eth.sign(hashToSeal, sealer)
    await this.chain.seal(signature, { from: sealer })
    return hashToSeal
  }

  async get (key) {
    let val = await this.store.get(this.web3.utils.toHex(key))
    return val
  }

  async getArray (key) {
    let encodedArray = await this.store.get(this.web3.utils.toHex(key))
    console.log(encodedArray)
    let decodedArray = rlp.decode(encodedArray)
    return decodedArray.map(item => '0x' + item.toString('hex').toLowerCase())
  }
}

module.exports = { Merklux }
