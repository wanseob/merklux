const chai = require('chai')
const BigNumber = web3.BigNumber
chai.use(require('chai-bignumber')(BigNumber)).should()
const Ganache = require('ganache-core')
const Web3 = require('web3')
const MerkluxCase = artifacts.require('MerkluxCase')
const MerkluxCaseManager = artifacts.require('MerkluxCaseManager')
const MerkluxStoreForCase = artifacts.require('MerkluxStoreForCase')
const SampleReducer = artifacts.require('BalanceIncrease')
const { rlpEncode } = require('./utils')
const ZERO = '0x0000000000000000000000000000000000000000000000000000000000000000'
const ZERO_ADDRESS = '0x0000000000000000000000000000000000000000'
const VALUE_TO_INCREASE = 8

let plasmaNet, plasma, caseManager

contract('MerkluxCase', async ([_, operator, sealer, accuser, user]) => {
  before(async () => {
    plasmaNet = Ganache.provider({
      logger: { log: () => {} },
      seed: 'merklux'
    })
    plasma = await runMerkluxOnPlasmaChain(plasmaNet, operator, sealer, user)
    caseManager = await MerkluxCaseManager.new(
      'V1',
      web3.utils.sha3(MerkluxCase.bytecode),
      web3.utils.sha3(MerkluxStoreForCase.bytecode)
    )
    await caseManager.registerReducer(SampleReducer.bytecode)
  })

  after(async () => {
    await plasmaNet.close(() => {})
  })

  it('should create a case with parent hash and child hash', async () => {
    let blockA = await plasma.contract.merkluxChain.getBlock(plasma.result.hashOfBlockA)
    let deployed = await initiateCase(
      caseManager,
      plasma.result.hashOfBlockA,
      blockA._previousBlock,
      600,
      sealer,
      accuser
    )
    let merkluxCase = await MerkluxCase.at(deployed.merkluxCase)
    await merkluxCase.submitOriginalBlock(
      ZERO,
      0,
      ZERO,
      ZERO,
      ZERO,
      ZERO_ADDRESS,
      '0x',
      { from: sealer }
    )

    await merkluxCase.submitTargetBlock(
      blockA._previousBlock,
      blockA._actionNum.toNumber(),
      blockA._state,
      blockA._references,
      blockA._actions,
      blockA._sealer,
      blockA._signature,
      { from: sealer }
    )
    let { references } = await getEvidence(
      plasmaNet,
      plasma.contract.merkluxStore,
      plasma.result.genesis,
      plasma.result.blockNumberA,
      user
    )
    for (let reference of references) {
      await merkluxCase.submitReference(
        reference._key,
        reference._value,
        reference._branchMask,
        reference._siblings,
        { from: sealer }
      )
    }
  })

  it('should create a case with parent hash and child hash', async () => {
    let blockA = await plasma.contract.merkluxChain.getBlock(plasma.result.hashOfBlockA)
    let blockB = await plasma.contract.merkluxChain.getBlock(plasma.result.hashOfBlockB)
    let deployed = await initiateCase(
      caseManager,
      plasma.result.hashOfBlockB,
      blockB._previousBlock,
      600,
      sealer,
      accuser
    )
    let merkluxCase = await MerkluxCase.at(deployed.merkluxCase)
    await merkluxCase.submitOriginalBlock(
      blockA._previousBlock,
      blockA._actionNum.toNumber(),
      blockA._state,
      blockA._references,
      blockA._actions,
      blockA._sealer,
      blockA._signature,
      { from: sealer }
    )
    await merkluxCase.submitTargetBlock(
      blockB._previousBlock,
      blockB._actionNum.toNumber(),
      blockB._state,
      blockB._references,
      blockB._actions,
      blockB._sealer,
      blockB._signature,
      { from: sealer }
    )
    let { references, actions } = await getEvidence(
      plasmaNet,
      plasma.contract.merkluxStore,
      plasma.result.blockNumberA,
      plasma.result.blockNumberB,
      user
    )
    for (let reference of references) {
      await merkluxCase.submitReference(
        reference._key,
        reference._value,
        reference._branchMask,
        reference._siblings,
        { from: sealer }
      )
    }
    for (let action of actions) {
      await merkluxCase.submitAction(
        action.base,
        action.from,
        action.actionNum.toNumber(),
        action.nonce,
        action.action,
        action.deployReducer,
        action.data,
        action.signature,
        { from: sealer }
      )
    }
    while (true) {
      try {
        await merkluxCase.runAction({ from: sealer })
      } catch (e) {
        break
      }
    }
    let caseResult = await merkluxCase.result.call()
    let caseResultAtManager = await caseManager.cases.call(plasma.result.hashOfBlockB)
    caseResult.should.equal(true)
    caseResultAtManager.result.should.equal(true)
  })
})

let runMerkluxOnPlasmaChain = async (plasmaNet, operator, sealer, user) => {
  let plasmaWeb3 = new Web3(plasmaNet)

  let PlasmaMerkluxFactory = artifacts.require('MerkluxFactory')
  let PlasmaMerkluxChain = artifacts.require('MerkluxChain')
  let PlasmaMerkluxStore = artifacts.require('MerkluxStore')
  PlasmaMerkluxFactory.setProvider(plasmaNet)
  PlasmaMerkluxChain.setProvider(plasmaNet)
  PlasmaMerkluxStore.setProvider(plasmaNet)
  let factory = await PlasmaMerkluxFactory.new(
    'V1',
    web3.utils.sha3(PlasmaMerkluxChain.bytecode),
    web3.utils.sha3(PlasmaMerkluxStore.bytecode),
    { from: operator }
  )
  await factory.createApp('BalanceIncreaser', { from: operator })
  await factory.deployChain('BalanceIncreaser', PlasmaMerkluxChain.bytecode, { from: operator })
  await factory.deployStore('BalanceIncreaser', PlasmaMerkluxStore.bytecode, { from: operator })
  await factory.complete('BalanceIncreaser', { from: operator })
  let deployed = await factory.getMerklux('BalanceIncreaser')

  let genesis = await plasmaWeb3.eth.getBlockNumber()
  let merkluxChain = await PlasmaMerkluxChain.at(deployed.chain)
  let merkluxStore = await PlasmaMerkluxStore.at(deployed.store)

  await deployReducer(merkluxChain, SampleReducer.bytecode, operator)
  await increaseBalance(merkluxChain, VALUE_TO_INCREASE, operator, user)
  await increaseBalance(merkluxChain, VALUE_TO_INCREASE, operator, user)
  await increaseBalance(merkluxChain, VALUE_TO_INCREASE, operator, user)
  let blockNumberA = await plasmaWeb3.eth.getBlockNumber()
  let hashOfBlockA = await sealBlock(merkluxChain, sealer)

  await increaseBalance(merkluxChain, VALUE_TO_INCREASE, operator, user)
  await increaseBalance(merkluxChain, VALUE_TO_INCREASE, operator, user)
  await increaseBalance(merkluxChain, VALUE_TO_INCREASE, operator, user)
  let blockNumberB = await plasmaWeb3.eth.getBlockNumber()
  let hashOfBlockB = await sealBlock(merkluxChain, sealer)
  return {
    contract: {
      merkluxChain,
      merkluxStore
    },
    result: {
      genesis,
      blockNumberA,
      blockNumberB,
      hashOfBlockA,
      hashOfBlockB
    }
  }
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

let getEvidence = async (plasmaNet, merkluxStore, blockNumberForOriginalState, blockNumberForTargetState, user) => {
  // Create snapshot for the original block
  let originalSnapshot = Ganache.provider({
    fork: plasmaNet,
    forkBlockNumber: blockNumberForOriginalState,
    logger: { log: console.log },
    seed: 'merklux'
  })
  // Create snapshot for the target block
  let targetSnapshot = Ganache.provider({
    fork: plasmaNet,
    forkBlockNumber: blockNumberForTargetState,
    logger: { log: console.log },
    seed: 'merklux'
  })

  let store = Object.assign({}, plasma.contract.merkluxStore)
  // Go to the snapshot B state
  store.contract.setProvider(targetSnapshot)

  // Gather action evidences
  let actions = []
  while (true) {
    try {
      actions.push(await store.actions.call(actions.length))
    } catch (e) {
      break
    }
  }

  // Gather referred keys
  let references = []
  let userBalanceAtSnapshotB = await store.get(user)
  let referredKeys = []
  while (true) {
    try {
      let key = await store.references.call(referredKeys.length)
      referredKeys.push(key)
    } catch (e) {
      break
    }
  }

  // Go to the snapshot A state
  store.contract.setProvider(originalSnapshot)

  // Gather references
  let userBalanceAtSnapshotA = await store.get(user)
  userBalanceAtSnapshotB.should.not.equal(userBalanceAtSnapshotA)
  for (let key of referredKeys) {
    let value = await store.get(key)
    if (value != null) {
      let reference = await store.getProof(key)
      references.push({ _key: key, ...reference })
    }
  }

  // Close forked chains
  originalSnapshot.close(() => {})
  targetSnapshot.close(() => {})

  // return values
  return {
    references,
    actions
  }
}

let initiateCase = async (caseFactory, target, parent, duration, defendant, accuser) => {
  await caseFactory.createCase(
    parent,
    target,
    defendant,
    duration,
    { from: accuser }
  )
  await caseFactory.deployCase(target, MerkluxCase.bytecode, { from: accuser })
  await caseFactory.deployStore(target, MerkluxStoreForCase.bytecode, { from: accuser })
  await caseFactory.openCase(target, { from: accuser })
  let { merkluxCase, store } = await caseFactory.getMerkluxCase(target)
  return { merkluxCase, store }
}
