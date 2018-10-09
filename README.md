# Merklux

[![Join the chat at https://gitter.im/commitground/merklux](https://badges.gitter.im/commitground/merklux.svg)](https://gitter.im/commitground/merklux?utm_source=badge&utm_medium=badge&utm_campaign=pr-badge&utm_content=badge)

##### latest released version
[![npm](https://img.shields.io/npm/v/merklux/latest.svg)](https://www.npmjs.com/package/merklux)
[![Build Status](https://travis-ci.org/commitground/merklux.svg?branch=master)](https://travis-ci.org/commitground/merklux)
[![Coverage Status](https://coveralls.io/repos/github/commitground/merklux/badge.svg?branch=master)](https://coveralls.io/github/commitground/merklux?branch=develop)

##### in progress
[![npm](https://img.shields.io/npm/v/merklux/next.svg)](https://www.npmjs.com/package/merklux)
[![Build Status](https://travis-ci.org/commitground/merklux.svg?branch=develop)](https://travis-ci.org/commitground/merklux)
[![Coverage Status](https://coveralls.io/repos/github/commitground/merklux/badge.svg?branch=develop)](https://coveralls.io/github/commitground/merklux?branch=develop)

[![JavaScript Style Guide](https://cdn.rawgit.com/standard/standard/master/badge.svg)](https://github.com/standard/standard)



## What is Merklux

Merklux is a merkleized unidirectional data flow for state verification across multiple chains. 
Originally, it is designed to provide a way to verify state transition of the plasma chain on the root chain. 
While we can reduce the transaction costs by submitting only the block headers of the plasma chain, we don't have a way to verify the plasma chain's state transition on the root chain.
It is because the nodes on the root chain cannot access the state of the plasma chain.
Using Merklux, we can reenact the state transition of the plasma chain on the root chain.
And for an efficiency Merklux manages the states with sharded namespaces and it reduces the transition costs for state transition verification.

And Merklux supports an accusatorial system to guarantee the state of the side chain.
[Plasma Plant](https://github.com/commitground/plasma-plant) is an implemenation of the plasma which uses an accusatorial system with Merklux.

## Pre-requisites

```bash
npm install -g truffle
npm install -g ganache
npm install
```


## Demo(work in progress)

Thus you can start the dApp for demonstration with the following command. 
(This demo dApp uses ReactJS and Drizzle)
```bash
npm run start
```
1. Pre requisites
    1. Run a root chain and a child chain.
1. Make state transitions on the child chain
    1. Deploy merklux smart contract to the child chain.
    1. Insert some items into the child chain.
    1. Get root edge from the Merklux of the child chain and store it as the original root.
    1. Get all nodes which are stored in the MerkluxTree at that time.
    1. Insert more items into the child chain.
    1. Get root edge from the Merklux of the child chain and store it as the target root.
1. Make a proof case on the root chain.
    1. Deploy a MerkluxCase to the root chain with the original root and the target root as its construtor's parameter.
    1. Commit all nodes
    1. Insert same items into the MerkluxCase of the root chain
    1. Verify its state tranisition
    
## Tests

Test cases include the information about how the functions work, but also includes a demo scenario.
Running and reading the test cases will help you understand how it works.

```bash
npm run test
```

## Features

1. State verification

    ```javascript
    const primary = '0xACCOUNT'
    it('should reenact the state transitions', async () => {
       // Deploy a MerkluxTree to the child chain
      const treeOnChildChain = await MerkluxTree.new({ from: primary })
 
      // Make state transitions
      await treeOnChildChain.insert('key1', 'val1', { from: primary })
      await treeOnChildChain.insert('key2', 'val2', { from: primary })
    
      // Snapshot the state
      const firstPhaseRootEdge = await treeOnChildChain.getRootEdge()
      const firstPhaseRootHash = firstPhaseRootEdge[2]
    
      // Get data to commit
      // getDataToCOmmit() is defined in the MerkluxCase.test.js
      const dataToCommit = await getDataToCommit(treeOnChildChain, firstPhaseRootHash);
 
      // Make extra state transitions
      await treeOnChildChain.insert('key3', 'val3', { from: primary })
      await treeOnChildChain.insert('key4', 'val4', { from: primary })
    
      // Snapshot again
      const secondPhaseRootEdge = await treeOnChildChain.getRootEdge()
    
      // Create a case to verify the state transition in another chain
      const caseOnRootChain = await MerkluxCase.new(...firstPhaseRootEdge, ...secondPhaseRootEdge, { from: primary })
      
      // Commit nodes and values
      const commitNodes = async (nodes) => {
        for (const node of nodes) {
          await caseOnRootChain.commitNode(...node, { from: primary })
        }
      }
      const commitValues = async (values) => {
        for (const value of values) {
          await caseOnRootChain.commitValue(value, { from: primary })
        }
      }
      await commitNodes(dataToCommit.nodes)
      await commitValues(dataToCommit.values)
    
      // It will be reverted when the committed nodes and values does not match with the firstPhaseRoot
      await caseOnRootChain.seal({ from: primary })
    
      // insert correct items
      await caseOnRootChain.insert('key3', 'val3', { from: primary })
      await caseOnRootChain.insert('key4', 'val4', { from: primary })
    
      // try to proof
      await merkluxCase.proof({ from: primary })
     
      // check it changes its status as SUCCESS
      assert.equal(
        (await merkluxCase.status()).toNumber(),
        Status.SUCCESS,
        'it should return its status as SUCCESS'
      )
    })
    ```
    Please check [MerkluxCase.test.js](./test/MerkluxCase.test.js) to get more detail information.

1. Sharded namespaces

    ```javascript
    To be updated
    ```


## Credits 

Merklux uses [Christian Reitwießner](https://github.com/chriseth)'s [patricia-trie](https://github.com/chriseth/patricia-trie) for its basic data structure.
And he already mentioned that it can be used for verifying evm-based sidechain executions. Thus, this is kind of an implementation case of his idea.

## Contributors

- [Wanseob Lim](https://github.com/james-lim)

## License

[MIT LICENSE](./LICENSE)
