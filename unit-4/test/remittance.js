const Remittance = artifacts.require("Remittance");
import { assertOkTx, getAndClearGas } from './util';
import { increaseTimeTo, duration } from 'zeppelin-solidity/test/helpers/increaseTime';
import latestTime from 'zeppelin-solidity/test/helpers/latestTime';
import assertRevert from 'zeppelin-solidity/test/helpers/assertRevert';

contract("Remittance", (accounts) => {
    var contract, startTime;
    var owner = accounts[1];
    var A = accounts[2];
    var B = accounts[3];
    var C = accounts[4];
    const valueA = web3.toWei(750, "finney");
    const valueB = web3.toWei(1250, "finney");
    const valueAB = web3.toWei(2000, "finney");

    const checkBalances = async (a, b, c) => {
        let balanceA = await contract.payments(A, {from: A});
        balanceA.should.be.bignumber.equal(a);
        let balanceB = await contract.payments(B, {from: B});
        balanceB.should.be.bignumber.equal(b);
        let balanceC = await contract.payments(C, {from: C});
        balanceC.should.be.bignumber.equal(c);
    }

    afterEach("print gas", () => {
        let gasUsed = getAndClearGas();
        console.log(`${gasUsed.toLocaleString()} gas used`);
    });

    beforeEach("new contract", async () => {
        contract = await Remittance.new({from: owner});
        startTime = latestTime();
    });

    it("two deposits and unlocks", async () => {
        let id1 = await contract.encode(A, B, C, "secret1", "secret2");
        let id2 = await contract.encode(A, B, C, "secret3", "secret4");
        // A deposits for B or C
        let until = startTime + duration.hours(3);
        await assertOkTx(contract.deposit(id1, B, C, until, {value: valueA, from: A}));
        // A tries do to another deposit with the same id
        await assertRevert(contract.deposit(id1, B, C, until, {value: valueB, from: A}));
        // A deposits for B with a new id
        await assertOkTx(contract.deposit(id2, B, C, until, {value: valueB, from: A}));
        // Even if somebody else steals the secrets, they still can't unlock
        await assertRevert(contract.unlock(id1, "secret1", "secret2", {from: owner}));
        await assertRevert(contract.unlock(id2, "secret3", "secret4", {from: owner}));
        // B unlocks
        await assertOkTx(contract.unlock(id1, "secret1", "secret2", {from: B}));
        // C unlocks
        await assertOkTx(contract.unlock(id2, "secret3", "secret4", {from: C}));
        // B & C got paid
        await checkBalances(0, valueA, valueB);
    });

    it("deposit and reclaim", async () => {
        // A deposits for B or C
        let until = startTime + duration.hours(3);
        let id = await contract.encode(A, B, C, "secret1", "secret2");
        await assertOkTx(contract.deposit(id, B, C, until, {value: valueA, from: A}));
        // 1 minute before deadline
        await increaseTimeTo(startTime + duration.hours(2) + duration.minutes(59));
        // A can't reclaim yet
        await assertRevert(contract.reclaim(id, {from: A}));
        // 1 minute after deadline
        await increaseTimeTo(startTime + duration.hours(3) + duration.minutes(1));
        // B or C can't reclaim
        await assertRevert(contract.reclaim(id, {from: B}));
        await assertRevert(contract.reclaim(id, {from: C}));
        // But A can
        await assertOkTx(contract.reclaim(id, {from: A}));
        // A got his money back
        await checkBalances(valueA, 0, 0);
    });
});