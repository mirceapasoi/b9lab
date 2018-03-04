const RockPaperScissors = artifacts.require("RockPaperScissors");
import { assertOkTx, getAndClearGas } from './util';
import { increaseTimeTo, duration } from 'zeppelin-solidity/test/helpers/increaseTime';
import latestTime from 'zeppelin-solidity/test/helpers/latestTime';
import assertRevert from 'zeppelin-solidity/test/helpers/assertRevert';

contract("RockPaperScissors", (accounts) => {
    var contract, startTime, secretA, secretB;
    var owner = accounts[1];
    var A = accounts[2];
    var B = accounts[3];
    const valueA = web3.toWei(200, "finney");
    const valueB = web3.toWei(400, "finney");
    const valueAB = web3.toWei(600, "finney");

    const checkBalances = async (a, b) => {
        let balanceA = await contract.payments(A, {from: A});
        balanceA.should.be.bignumber.equal(a);
        let balanceB = await contract.payments(B, {from: B});
        balanceB.should.be.bignumber.equal(b);
    }

    afterEach("print gas", () => {
        let gasUsed = getAndClearGas();
        console.log(`${gasUsed.toLocaleString()} gas used`);
    });

    beforeEach("new contract", async () => {
        contract = await RockPaperScissors.new({from: owner});
        startTime = latestTime();
        secretA = await contract.hashMove.call(A, B, 2, "playerA");
        secretB = await contract.hashMove.call(B, A, 1, "playerB");
    });

    it("should let you withdraw after 8 hours", async () => {
        // A plays in secret (PAPER)
        await assertOkTx(contract.play(B, secretA, {from: A, value: valueA}));
        // 59 minutes
        await increaseTimeTo(startTime + duration.hours(7) + duration.minutes(59));
        // Can't cancel or reward
        await assertRevert(contract.cancel(B, {from: A}));
        await assertRevert(contract.cancel(A, {from: B}));
        await assertRevert(contract.rewardWinner(B, {from: A}));
        await assertRevert(contract.rewardWinner(A, {from: B}));
        // 61 minutes
        await increaseTimeTo(startTime + duration.hours(8) + duration.minutes(1));
        await assertOkTx(contract.cancel(B, {from: A}));
        await checkBalances(valueA, 0);
    });

    it("shouldn't let anybody withdraw for 8 hours after both played", async () => {
        // A plays in secret (PAPER)
        await assertOkTx(contract.play(B, secretA, {from: A, value: valueA}));
        // 1 hour delay
        await increaseTimeTo(startTime + duration.hours(1));
        // B plays in secret (ROCK)
        await assertOkTx(contract.play(A, secretB, {from: B, value: valueB}));
        // almost 8 more hours
        await increaseTimeTo(startTime + duration.hours(8) + duration.minutes(59));
        // Try to withdraw
        await assertRevert(contract.cancel(B, {from: A}));
        await assertRevert(contract.cancel(A, {from: B}));
        await assertRevert(contract.rewardWinner(B, {from: A}));
        await assertRevert(contract.rewardWinner(A, {from: B}));
        // 9 hours and 1 minute after
        await increaseTimeTo(startTime + duration.hours(9) + duration.minutes(1));
        await assertOkTx(contract.cancel(B, {from: A}));
        // Both get money back
        await checkBalances(valueA, valueB);
    });


    it("should let player withdraw after one revealed & other didn't for 8 hours", async () => {
        // A plays in secret (PAPER)
        await assertOkTx(contract.play(B, secretA, {from: A, value: valueA}));
        // A plays in secret (PAPER)
        await assertOkTx(contract.play(A, secretB, {from: B, value: valueB}));
        // A reveals
        await assertOkTx(contract.reveal(B, 2, "playerA", {from: A}));
        // almost 8 more hours
        await increaseTimeTo(startTime + duration.hours(7) + duration.minutes(59));
        // Try to withdraw
        await assertRevert(contract.cancel(A, {from: B}));
        await assertRevert(contract.cancel(B, {from: A}));
        await assertRevert(contract.rewardWinner(B, {from: A}));
        await assertRevert(contract.rewardWinner(A, {from: B}));
        // 8 hours and 1 minute
        await increaseTimeTo(startTime + duration.hours(8) + duration.minutes(1));
        // A cancels game
        await assertOkTx(contract.cancel(B, {from: A}));
        // A gets the money
        await checkBalances(valueAB, 0);
    });

    it("should play", async () => {
        // B plays in secret (ROCK)
        await assertOkTx(contract.play(A, secretB, {from: B, value: valueB}));
        // A plays in secret (PAPER)
        await assertOkTx(contract.play(B, secretA, {from: A, value: valueA}));
        // Can't cancel or reward
        await assertRevert(contract.cancel(B, {from: A}));
        await assertRevert(contract.cancel(A, {from: B}));
        await assertRevert(contract.rewardWinner(B, {from: A}));
        await assertRevert(contract.rewardWinner(A, {from: B}));
        // A reveals
        await assertOkTx(contract.reveal(B, 2, "playerA", {from: A}));
        // B reveals
        await assertOkTx(contract.reveal(A, 1, "playerB", {from: B}));
        // Can't cancel anymore
        await assertRevert(contract.cancel(B, {from: A}));
        await assertRevert(contract.cancel(A, {from: B}));
        // B triggers reward, but A won (PAPER > ROCK)
        await assertOkTx(contract.rewardWinner(A, {from: B}));
        // check balances
        await checkBalances(valueAB, 0);
    });
});