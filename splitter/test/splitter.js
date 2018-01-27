const BigNumber = web3.BigNumber;
require('chai').use(require('chai-bignumber')(BigNumber)).should();

const Splitter = artifacts.require("Splitter");
const HasNoEther = artifacts.require("HasNoEther");

// Utility for error
const assertError = (e) => assert.include(e.message, 'revert', "contract din't throw");

const getBalances = (addresses) => {
    let result = [];
    for (let addr of addresses) {
        let b = web3.eth.getBalance(addr);
        result.push(b);
    }
    return result;
}

const printBalances = (prefix, addresses, unit = "ether") => {
    const balances = getBalances(addresses);
    console.debug(prefix, balances.map(b => web3.fromWei(b, unit).toNumber()).join('\t'));
    return balances;
}

// Test split
const testSplit = async (contract, A, B, C, call) => {
    const addresses = [contract.address, A, B, C];
    // get before balances
    const before = printBalances('Before:', addresses);

    // make call
    try {
        let result = await call;
        // print logs from call
        for (let log of result.logs) {
            let value = web3.fromWei(log.args.value, "ether").toNumber();
            console.debug(log.event, value);
        }
    } catch (error) {
        console.error(error.message);
        throw error;
    }

    web3.eth.getBalance(A).should.be.bignumber.below(before[1]);

    // withdraw
    let bError, cError;
    try {
        await contract.withdrawPayments({from: B});
        web3.eth.getBalance(B).should.be.bignumber.above(before[2]);
    } catch (error) {
        console.debug(`B withdrawal: ${error.message}`);
        bError = error;
    }
    try {
        await contract.withdrawPayments({from: C});
        web3.eth.getBalance(C).should.be.bignumber.above(before[3]);
    } catch (error) {
        console.debug(`C withdrawal: ${error.message}`);
        cError = error;
    }

    // get after balances
    printBalances('After:', addresses);

    return [bError, cError];
}


contract("Splitter", (accounts) => {
    var contract, noEther;
    var owner = accounts[1];
    var A = accounts[2];
    var B = accounts[3];
    var C = accounts[4];
    const oneUnit = web3.toWei(100, "finney");
    const twoUnits = web3.toWei(200, "finney");

    before("set ether trap", async () => {
        // setup contract that refuses to accept ether
        noEther = await HasNoEther.new({from: owner});
    })

    beforeEach("new contract", async () => {
        contract = await Splitter.new({from: owner});
    })

    // Ownable
    it("should be owned by owner", async () => {
        let actualOwner = await contract.owner();
        assert.strictEqual(actualOwner, owner, "contract is not owned by owner");
    });

    // Destroyable
    it("should be killed by owner", async () => {
        assert.notEqual(web3.eth.getCode(contract.address), "0x0");
        let result = await contract.destroy({from: owner});
        assert.isOk(result);
        assert.strictEqual(web3.eth.getCode(contract.address), "0x0");
    });

    it("should not be killed by others", async () => {
        try {
            await contract.destroy({from: A});
        } catch (error) {
            assertError(error);
        }
    });

    // Pausable
    it("should be paused/unpaused by owner", async () => {
        let result = await contract.pause({from: owner});
        assert.isOk(result);
        result = await contract.unpause({from: owner});
        assert.isOk(result);
    });

    it("should not be paused by others", async () => {
        try {
            await contract.pause({from: A});
        } catch (error) {
            assertError(error);
        }
    });

    it("should not split() when paused", async () => {
        await contract.pause({from: owner});
        try {
            await contract.split(B, C, {from: A, value: twoUnits});
        } catch (error) {
            assertError(error);
        }
    });

    // Split
    it("split() when A sends ETH", async () => {
        await testSplit(contract, A, B, C, contract.split(B, C, {from: A, value: oneUnit}));
    });

    it("should not eat ETH and allow refunds", async () => {
        let C = noEther.address;
        const [bError, cError] = await testSplit(contract, A, B, C, contract.split(B, C, {from: A, value: twoUnits}));
        assert.isNotOk(bError);
        assert.include(cError.message, 'unlock', "contract din't throw");
    });
});