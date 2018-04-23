const Remittance = artifacts.require("Remittance");
import { assertOkTx, getAndClearGas, measureTx } from './util';
import { increaseTimeTo, duration } from 'zeppelin-solidity/test/helpers/increaseTime';
import latestTime from 'zeppelin-solidity/test/helpers/latestTime';
import assertRevert from 'zeppelin-solidity/test/helpers/assertRevert';

contract("Remittance", (accounts) => {
    var contract, startTime;
    var owner = accounts[1];
    var A = accounts[2];
    var B = accounts[3];
    const valueA = web3.toWei(750, "finney");
    const valueB = web3.toWei(1250, "finney");
    const valueAB = web3.toWei(2000, "finney");

    const checkBalances = async (a, b, c) => {
        let balanceA = await contract.payments(A, {from: A});
        balanceA.should.be.bignumber.equal(a);
        let balanceB = await contract.payments(B, {from: B});
        balanceB.should.be.bignumber.equal(b);
    }

    afterEach("print gas", () => {
        let gasUsed = getAndClearGas();
        console.log(`\tTest: ${getAndClearGas().toLocaleString()} gas used`);
    });

    beforeEach("new contract", async () => {
        contract = await Remittance.new({from: owner});
        await measureTx(contract.transactionHash);
        startTime = latestTime();
        console.log(`\tSetup: ${getAndClearGas().toLocaleString()} gas used`);
    });

    it("A deposits for B, B unlocks", async () => {
        let id = await contract.encode.call(B, "secret1", "secret2");
        // A deposits for B or C
        let until = startTime + duration.hours(3);
        await assertOkTx(contract.deposit(id, B, until, {value: valueA, from: A}));
        // A tries do to another deposit with the same id
        await assertRevert(contract.deposit(id, B, until, {value: valueB, from: A}));
        // Even if somebody else steals the secrets, they still can't unlock
        await assertRevert(contract.unlock("secret1", "secret2", {from: owner}));
        // B unlocks
        await assertOkTx(contract.unlock("secret1", "secret2", {from: B}));
        // B got paid
        await checkBalances(0, valueA, 0);
        // Can't re-use id
        await assertRevert(contract.deposit(id, B, until, {value: valueB, from: A}));
    });

    it("A deposits for B, A reclaims", async () => {
        // A deposits for B or C
        let until = startTime + duration.hours(3);
        let id = await contract.encode.call(B, "secret1", "secret2");
        await assertOkTx(contract.deposit(id, B, until, {value: valueA, from: A}));
        // 1 minute before deadline
        await increaseTimeTo(startTime + duration.hours(2) + duration.minutes(59));
        // A can't reclaim yet
        await assertRevert(contract.reclaim(id, {from: A}));
        // 1 minute after deadline
        await increaseTimeTo(startTime + duration.hours(3) + duration.minutes(1));
        // B can't reclaim
        await assertRevert(contract.reclaim(id, {from: B}));
        // But A can
        await assertOkTx(contract.reclaim(id, {from: A}));
        // A got his money back
        await checkBalances(valueA, 0, 0);
    });
});