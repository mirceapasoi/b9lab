const Splitter = artifacts.require("Splitter");
import { assertOkTx, getAndClearGas, measureTx } from './util';
import assertRevert from 'zeppelin-solidity/test/helpers/assertRevert';

contract("Splitter", (accounts) => {
    var contract;
    var owner = accounts[1];
    var A = accounts[2];
    var B = accounts[3];
    var C = accounts[4];
    const oneUnit = web3.toWei(100, "finney");
    const twoUnits = web3.toWei(200, "finney");

    const checkBalances = async (a, b, c) => {
        let balanceA = await contract.payments(A, {from: A});
        balanceA.should.be.bignumber.equal(a);
        let balanceB = await contract.payments(B, {from: B});
        balanceB.should.be.bignumber.equal(b);
        let balanceC = await contract.payments(C, {from: C});
        balanceC.should.be.bignumber.equal(c);
    }

    afterEach("print gas", () => {
        console.log(`\tTest: ${getAndClearGas().toLocaleString()} gas used`);
    })

    beforeEach("new contract", async () => {
        contract = await Splitter.new({from: owner});
        await measureTx(contract.transactionHash);
        console.log(`\tSetup: ${getAndClearGas().toLocaleString()} gas used`);
    })

    // Ownable
    it("should be owned by owner", async () => {
        let actualOwner = await contract.owner();
        assert.strictEqual(actualOwner, owner, "contract is not owned by owner");
    });

    // Destroyable
    it("should be killed by owner", async () => {
        assert.notEqual(web3.eth.getCode(contract.address), "0x0");
        await assertOkTx(contract.destroy({from: owner}));
        assert.strictEqual(web3.eth.getCode(contract.address), "0x0");
    });

    it("should not be killed by others", async () => {
        await assertRevert(contract.destroy({from: A}));
    });

    // Pausable
    it("should be paused/unpaused by owner", async () => {
        await assertOkTx(contract.pause({from: owner}));
        await assertOkTx(contract.unpause({from: owner}));
    });

    it("should not be paused by others", async () => {
        await assertRevert(contract.pause({from: A}));
    });

    it("should not split() when paused", async () => {
        await assertOkTx(contract.pause({from: owner}));
        await assertRevert(contract.split(B, C, {from: A, value: twoUnits}));
    });

    // Split
    it("split() when A sends ETH", async () => {
        // A splits between B & C
        await assertOkTx(contract.split(B, C, {from: A, value: twoUnits}));
        await checkBalances(0, oneUnit, oneUnit);
    });
});