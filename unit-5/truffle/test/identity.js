const Identity = artifacts.require("Identity");
import { assertOkTx, getAndClearGas } from './util';
import assertRevert from 'zeppelin-solidity/test/helpers/assertRevert';

contract("Identity", (accounts) => {
    let contract;
    let manager1 = accounts[0];
    let manager2 = accounts[1];
    let action1 = accounts[2];
    let action2 = accounts[3];
    let action3 = accounts[4];
    let claim = accounts[5];
    let encrypt = accounts[6];
    let other = accounts[7];

    const Purpose = {
        MANAGEMENT: 1,
        ACTION: 2,
    };
    const KeyType = {
        ECDSA: 1,
    }

    let addKey = async (address, purpose) => {
        let key = await contract.addressToKey(address);
        await assertOkTx(contract.addKey(key, purpose, KeyType.ECDSA));
    }

    afterEach("print gas", () => {
        console.log(`${getAndClearGas().toLocaleString()} gas for test`);
    })

    beforeEach("new contract", async () => {
        contract = await Identity.new({from: manager1});
        await addKey(manager2, Purpose.MANAGEMENT);
        await addKey(action1, Purpose.ACTION);
        await addKey(action2, Purpose.ACTION);
        console.log(`${getAndClearGas().toLocaleString()} gas for setup`);
    })

    // Destroyable
    it("should be killed by management keys", async () => {
        assert.notEqual(web3.eth.getCode(contract.address), "0x0");
        await assertOkTx(contract.destroyAndSend(manager1, {from: manager2}));
        assert.strictEqual(web3.eth.getCode(contract.address), "0x0");
    });

    it("should not be killed by others", async () => {
        await assertRevert(contract.destroyAndSend(action1, {from: action1}));
    });

    // Pausable
    it("should be paused/unpaused by management keys", async () => {
        await assertOkTx(contract.pause({from: manager1}));
        // Can't add key
        let key = await contract.addressToKey(action3);
        await assertRevert(contract.addKey(key, Purpose.ACTION, KeyType.ECDSA));
        await assertOkTx(contract.unpause({from: manager2}));
    });

    it("should not be paused by others", async () => {
        await assertRevert(contract.pause({from: action1}));
    });

    // TODO: Test getters
    // TODO: Test delete
});