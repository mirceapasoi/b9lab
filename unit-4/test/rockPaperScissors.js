const RockPaperScissors = artifacts.require("RockPaperScissors");
const { assertError, assertResult, getAndClearGas } = require('./util.js');

const encode = (move, secret) => {
    // Move is 0, 1, 2, 3. Since we're using enums it gets encoded as uint8, so
    // we need to pad it with one zero.
    let packed = "0x0" + move.toString();
    // Add secret string, but remove 0x
    packed += web3.fromAscii(secret).slice(2);
    return web3.sha3(packed, {encoding: 'hex'});
}

contract("RockPaperScissors", (accounts) => {
    var contract, noEther;
    var owner = accounts[1];
    var A = accounts[2];
    var B = accounts[3];
    const valueA = web3.toWei(200, "finney");
    const valueB = web3.toWei(400, "finney");
    const valueAB = web3.toWei(600, "finney");

    afterEach("print gas", () => {
        let gasUsed = getAndClearGas();
        console.log(`${gasUsed.toLocaleString()} gas used`);
    });

    beforeEach("new contract", async () => {
        contract = await RockPaperScissors.new({from: owner});
    });

    it("should play", async () => {
        // A enrolls
        let r = await contract.enroll(B, {from: A, value: valueA});
        assertResult(r);
        // B enrolls
        r = await contract.enroll(A, {from: B, value: valueB});
        assertResult(r);
        // B plays in secret (ROCK)
        let secretB = encode(1, "playerB");
        r = await contract.play(A, secretB, {from: B});
        assertResult(r);
        // A plays in secret (PAPER)
        let secretA = encode(2, "playerA");
        r = await contract.play(B, secretA, {from: A});
        assertResult(r);
        // A reveals
        r = await contract.reveal(B, 2, "playerA", {from: A});
        assertResult(r);
        // B reveals
        r = await contract.reveal(A, 1, "playerB", {from: B});
        assertResult(r);
        // B triggers reward, but A won (PAPER > ROCK)
        r = await contract.rewardWinner(A, {from: B});
        assertResult(r);
        // check balances
        let balanceA = await contract.payments(A, {from: A});
        balanceA.should.be.bignumber.equal(valueAB);
        let balanceB = await contract.payments(B, {from: B});
        balanceB.should.be.bignumber.equal(0);
    });
});