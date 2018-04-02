const Identity = artifacts.require("Identity");
import colors from 'colors';
import { assertOkTx, getAndClearGas, measureTx } from './util';

// Constants
export const Purpose = {
    MANAGEMENT: 1,
    ACTION: 2,
    CLAIM: 3,
    ENCRYPT: 4
};

export const KeyType = {
    ECDSA: 1,
};

export const ClaimType = {
    BIOMETRIC: 1,
    RESIDENCE: 2,
    REGISTRY: 3,
    PROFILE: 4,
    LABEL: 5
}

export const Scheme = {
    ECDSA: 1,
    RSA: 2,
    CONTRACT: 3,
    URI: 4,
    RAW: 5
}

export const assertKeyCount = async (contract, purpose, count) => {
    let keys = await contract.getKeysByPurpose(purpose);
    assert.equal(keys.length, count);
};

// Setup test environment
export const setupTest = async (accounts, init12, total12, init34, total34) => {
    assert(2 * total12 + 2 * total34 <= accounts.length);

    // Generate addresses
    let addr = {
        manager: accounts.slice(0, total12),
        action: accounts.slice(total12, total12 * 2),
        claim: accounts.slice(total12 * 2, total12 * 2 + total34),
        encrypt:  accounts.slice(total12 * 2 + total34, total12 * 2 + total34 * 2)
    };

    // Deploy contract
    let contract = await Identity.new({from: addr.manager[0]});
    await measureTx(contract.transactionHash);

    // Generate keys
    let addressesToKeys = async (addresses) => {
        let keys = [];
        for (let addr of addresses) {
            let key = await contract.addrToKey(addr);
            keys.push(key);
        }
        return keys;
    };
    let keys = {
        manager: await addressesToKeys(addr.manager),
        action: await addressesToKeys(addr.action),
        claim: await addressesToKeys(addr.claim),
        encrypt: await addressesToKeys(addr.encrypt)
    };

    // Add some keys
    for (let i = 1; i < init12; i++) {
        await assertOkTx(contract.addKey(keys.manager[i], Purpose.MANAGEMENT, KeyType.ECDSA, {from: addr.manager[0]}));
    }
    for (let i = 0; i < init12; i++) {
        await assertOkTx(contract.addKey(keys.action[i], Purpose.ACTION, KeyType.ECDSA, {from: addr.manager[0]}));
    }
    for (let i = 0; i < init34; i++) {
        await assertOkTx(contract.addKey(keys.claim[i], Purpose.CLAIM, KeyType.ECDSA, {from: addr.manager[0]}));
        await assertOkTx(contract.addKey(keys.encrypt[i], Purpose.ENCRYPT, KeyType.ECDSA, {from: addr.manager[0]}));
    }

    console.debug(`Setup: ${getAndClearGas().toLocaleString()} gas (${init12 + init34}/${total12 + total34} keys added)`.grey);

    return {
        contract,
        addr,
        keys
    }
}