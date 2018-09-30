var MerkluxTree = artifacts.require("MerkluxTree");

contract('MerkluxTree', async(accounts)=> {
  it("should something", async () => {
    let instance = await MerkluxTree.deployed();
    await instance.insert.call("ONE", "ONE");
    await instance.insert.call("TWO", "TWO");
    await instance.insert.call("THREE", "THREE");
    await instance.insert.call("FOUR", "FOUR");
    console.log(await instance.getValue.call("ONE"));
    console.log(await instance.getValue.call("TWO"));
    console.log(await instance.getValue.call("THREE"));
    console.log(await instance.getValue.call("FOUR"));
  })
});
