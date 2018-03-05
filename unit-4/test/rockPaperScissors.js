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
    const Move = {
        ROCK: 1,
        PAPER: 2,
        SCISSORS: 3
    };

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
        // A plays in secret (PAPER)
        secretA = await contract.hashMove.call(A, B, Move.PAPER, "playerA");
        // B plays in secret (ROCK)
        secretB = await contract.hashMove.call(B, A, Move.ROCK, "playerB");
    });

    it("should let player 1 withdraw after 8 hours", async () => {
        // A plays PAPER
        await assertOkTx(contract.playFirst(B, secretA, {from: A, value: valueA}));
        // 59 minutes
        await increaseTimeTo(startTime + duration.hours(7) + duration.minutes(59));
        // Can't cancel
        await assertRevert(contract.cancel(B, {from: A}));
        await assertRevert(contract.cancel(A, {from: B}));
        // 61 minutes
        await increaseTimeTo(startTime + duration.hours(8) + duration.minutes(1));
        // A cancels
        await assertOkTx(contract.cancel(B, {from: A}));
        await checkBalances(valueA, 0);
    });

    it("should let player 2 refuse to play after 8 hours", async () => {
        // A plays PAPER
        await assertOkTx(contract.playFirst(B, secretA, {from: A, value: valueA}));
        // 59 minutes
        await increaseTimeTo(startTime + duration.hours(7) + duration.minutes(59));
        // Can't cancel
        await assertRevert(contract.cancel(B, {from: A}));
        await assertRevert(contract.cancel(A, {from: B}));
        // 61 minutes
        await increaseTimeTo(startTime + duration.hours(8) + duration.minutes(1));
        // B cancels
        await assertOkTx(contract.cancel(A, {from: B}));
        await checkBalances(valueA, 0);
    });


    it("should let player 2 win if player 1 forfeits after 8 hours", async () => {
        // A plays PAPER
        await assertOkTx(contract.playFirst(B, secretA, {from: A, value: valueA}));
        // 1 hour delay
        await increaseTimeTo(startTime + duration.hours(1));
        // B plays ROCK
        await assertOkTx(contract.playSecond(A, Move.ROCK, {from: B, value: valueB}));
        // almost 8 more hours
        await increaseTimeTo(startTime + duration.hours(8) + duration.minutes(59));
        // Try to withdraw
        await assertRevert(contract.cancel(B, {from: A}));
        await assertRevert(contract.cancel(A, {from: B}));
        // 9 hours and 1 minute after
        await increaseTimeTo(startTime + duration.hours(9) + duration.minutes(1));
        // A cancels
        await assertOkTx(contract.cancel(B, {from: A}));
        // B gets the money since he revealed
        await checkBalances(0, valueAB);
    });

    it("should let player 2 win if player 1 doesn't reveal after 8 hours", async () => {
        // A plays PAPER
        await assertOkTx(contract.playFirst(B, secretA, {from: A, value: valueA}));
        // 1 hour delay
        await increaseTimeTo(startTime + duration.hours(1));
        // B plays ROCK
        await assertOkTx(contract.playSecond(A, Move.PAPER, {from: B, value: valueB}));
        // almost 8 more hours
        await increaseTimeTo(startTime + duration.hours(8) + duration.minutes(59));
        // Try to withdraw
        await assertRevert(contract.cancel(B, {from: A}));
        await assertRevert(contract.cancel(A, {from: B}));
        // 9 hours and 1 minute after
        await increaseTimeTo(startTime + duration.hours(9) + duration.minutes(1));
        // B cancels
        await assertOkTx(contract.cancel(A, {from: B}));
        // B gets the money since he revealed
        await checkBalances(0, valueAB);
    });

    it("should play", async () => {
        // B plays ROCK
        await assertOkTx(contract.playFirst(A, secretB, {from: B, value: valueB}));
        // A plays PAPER
        await assertOkTx(contract.playSecond(B, Move.PAPER, {from: A, value: valueA}));
        // Can't cancel
        await assertRevert(contract.cancel(B, {from: A}));
        await assertRevert(contract.cancel(A, {from: B}));
        // B reveals
        await assertOkTx(contract.revealFirst(A, Move.ROCK, "playerB", {from: B}));
        // Can't cancel anymore because there's no game
        await assertRevert(contract.cancel(B, {from: A}));
        await assertRevert(contract.cancel(A, {from: B}));
        // A won, B lost
        await checkBalances(valueAB, 0);
    });
});