const Splitter = artifacts.require("Splitter");
const HasNoEther = artifacts.require("HasNoEther");

// Utility for error
const assertError = (e) => assert.include(e.message, 'revert', "contract din't throw");

const getBalances = async (addresses, unit = "ether") => {
    let result = [];
    for (let addr of addresses) {
        let b = await web3.eth.getBalance(addr);
        result.push(web3.fromWei(b, unit).toNumber());
    }
    return result;
}

// Test split
const testThree = async (instance, A, B, C, call) => {
    const addresses = [instance.address, A, B, C];
    // get before balances
    let before = await getBalances(addresses);
    console.log('Before:', before.join('\t'));
    // make call
    try {
        let result = await call;
        // print logs from call
        for (let log of result.logs) {
            let value = web3.fromWei(log.args.value, "ether" ).toNumber();
            console.debug(log.event, value, log.args.success);
        }
    } catch (error) {
        console.error(error.message);
    }
    // get after balances
    let after = await getBalances(addresses);
    console.log('After:', after.join('\t'));

    const beforeSum = before.reduce((a, b) => a + b, 0);
    const afterSum = after.reduce((a, b) => a + b, 0);
    assert.notEqual(beforeSum, afterSum);
}


contract("Splitter", (accounts) => {
    var instance, noEther;
    var owner = accounts[1];
    var alice = accounts[2];
    var bob = accounts[3];
    var carol = accounts[4];
    const oneEth = web3.toWei(1, "ether");
    const twoEth = web3.toWei(2, "ether");

    before("set ether trap", async () => {
        // setup contract that refuses to accept ether
        noEther = await HasNoEther.new({from: owner});
    })

    beforeEach("new contract", async () => {
        instance = await Splitter.new(alice, bob, carol, {from: owner});
    })

    // Ownable
    it("should be owned by owner", async () => {
        let actualOwner = await instance.owner();
        assert.strictEqual(actualOwner, owner, "contract is not owned by owner");
    });

    // Destroyable
    it("should be killed by owner", async () => {
        let result = await instance.destroy({from: owner});
        assert.isOk(result);
    });

    it("should not be killed by others", async () => {
        try {
            await instance.destroy({from: alice});
        } catch (error) {
            assertError(error);
        }
    });

    // Pausable
    it("should be paused/unpaused by owner", async () => {
        let result = await instance.pause({from: owner});
        assert.isOk(result);
        result = await instance.unpause({from: owner});
        assert.isOk(result);
    });

    it("should not be paused by others", async () => {
        try {
            await instance.pause({from: alice});
        } catch (error) {
            assertError(error);
        }
    });

    it("should not splitBobCarol() when paused", async () => {
        await instance.pause({from: owner});
        try {
            await instance.splitBobCarol({from: alice, value: twoEth});
        } catch (error) {
            assertError(error);
        }
    });

    it("should not split() when paused", async () => {
        await instance.pause({from: owner});
        try {
            await instance.split(bob, carol, {from: alice, value: twoEth});
        } catch (error) {
            assertError(error);
        }
    });

    // Split
    it("should not splitBobCarol() from non-Alice", async () => {
        let before = await web3.eth.getBalance(instance.address).toNumber();
        try {
            await instance.splitBobCarol({from: owner, value: oneEth});
        } catch (error) {
            assertError(error);
        }
        let after =  await web3.eth.getBalance(instance.address).toNumber();
        assert.strictEqual(before, after, "contract trapped ether!");
    });

    it("splitBobCarol() when Alice sends 2 ETH", async () => {
        await testThree(instance, alice, bob, carol, instance.splitBobCarol({from: alice, value: twoEth}));
    });

    it("split(B, C) when others send 1 ETH", async () => {
        let A = accounts[5], B = accounts[6], C = accounts[7];
        await testThree(instance, A, B, C, instance.split(B, C, {from: A, value: oneEth}));
    });

    it("should not eat 2 ETH and allow refunds", async () => {
        let A = alice, B = bob, C = noEther.address;
        await testThree(instance, A, B, C, instance.split(B, C, {from: A, value: twoEth}));
        // Can't refund B
        try {
            await instance.withdrawPayments({from: B});
        } catch (error) {
            assertError(error);
        }
        await instance.withdrawPayments({from: A});
        // Refund A half
        let balances = await getBalances([instance.address, A, B, C]);
        console.log('Refund:', balances.join('\t'));
    });
});