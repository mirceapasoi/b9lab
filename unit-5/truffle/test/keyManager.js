import assertRevert from 'zeppelin-solidity/test/helpers/assertRevert';
import { setupTest, assertKeyCount, Purpose, KeyType } from './base';
import { printTestGas, printTotalGas, assertOkTx } from './util';

contract("KeyManager", async (accounts) => {
    let contract, addr, keys;

    afterEach("print gas", printTestGas);
    after("all done", printTotalGas);

    beforeEach("new contract", async () => {
        ({ contract, addr, keys } = await setupTest(accounts, 2, 3, 0, 1));
    })

    describe("addKey", async () => {
        it("should not add the same key twice", async () => {
            // Start with 2
            await assertKeyCount(contract, Purpose.ACTION, 2);

            await assertOkTx(contract.addKey(keys.action[2], Purpose.ACTION, KeyType.ECDSA, {from: addr.manager[0]}));
            await assertOkTx(contract.addKey(keys.action[2], Purpose.ACTION, KeyType.ECDSA, {from: addr.manager[1]}));

            // End with 3
            await assertKeyCount(contract, Purpose.ACTION, 3);
        });

        it ("should add only for management keys", async () => {
            // Start with 2
            await assertKeyCount(contract, Purpose.ACTION, 2);

            await assertRevert(contract.addKey(keys.action[2], Purpose.ACTION, KeyType.ECDSA, {from: addr.action[0]}));
            await assertRevert(contract.addKey(keys.action[2], Purpose.ACTION, KeyType.ECDSA, {from: addr.action[1]}));

            // End with 2
            await assertKeyCount(contract, Purpose.ACTION, 2);
        });
    });

    describe("removeKey", async () => {
        it("should remove existing key", async () => {
            // Start with 2
            await assertKeyCount(contract, Purpose.MANAGEMENT, 2);

            // Remove 1
            await assertOkTx(contract.removeKey(keys.manager[1], Purpose.MANAGEMENT, {from: addr.manager[0]}));
            await assertKeyCount(contract, Purpose.MANAGEMENT, 1);

            // Remove self
            await assertOkTx(contract.removeKey(keys.manager[0], Purpose.MANAGEMENT, {from: addr.manager[0]}));
            await assertKeyCount(contract, Purpose.MANAGEMENT, 0);
        });

        it("should remove only for management keys", async () => {
            // Start with 2
            await assertKeyCount(contract, Purpose.MANAGEMENT, 2);

            await assertRevert(contract.removeKey(keys.manager[0], Purpose.MANAGEMENT, {from: addr.action[0]}));
            await assertRevert(contract.removeKey(keys.manager[1], Purpose.MANAGEMENT, {from: addr.action[1]}));

            // End with 2
            await assertKeyCount(contract, Purpose.MANAGEMENT, 2);
        });

        it ("should ignore keys that don't exist", async () => {
            await assertKeyCount(contract, Purpose.CLAIM, 0);
            await assertKeyCount(contract, Purpose.ENCRYPT, 0);

            await assertOkTx(contract.removeKey(keys.claim[0], Purpose.CLAIM, {from: addr.manager[0]}));
            await assertOkTx(contract.removeKey(keys.encrypt[0], Purpose.ENCRYPT, {from: addr.manager[0]}));
        });
    });
});