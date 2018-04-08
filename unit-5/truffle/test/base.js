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
    CONTRACT: 3
}

export const assertKeyCount = async (contract, purpose, count) => {
    let keys = await contract.getKeysByPurpose(purpose);
    assert.equal(keys.length, count);
};

// Setup test environment
export const setupTest = async (accounts, init, total) => {
    let totalSum = total.reduce((a, b) => a + b);
    let initSum = init.reduce((a, b) => a + b);
    // Check we have enough accounts
    assert(initSum <= totalSum && totalSum <= accounts.length);
    // Generate keys using keccak256 / sha3
    accounts = accounts.map(a => [a, web3.sha3(a, {encoding: 'hex'})]);
    // Sort by keys (useful for contract constructor)
    accounts.sort((a, b) => a[1].localeCompare(b[1]));

    // Put keys in maps
    const idxToPurpose = ['manager', 'action', 'claim', 'encrypt'];
    let addr = {}, keys = {};
    for (let i = 0, j = 0; i < total.length; i++) {
        // Slice total[i] accounts
        let slice = accounts.slice(j, j + total[i]);
        j += total[i];
        let purpose = idxToPurpose[i];
        addr[purpose] = slice.map(a => a[0]);
        keys[purpose] = slice.map(a => a[1]);
    }

    // Init keys
    let initKeys = [], initPurposes = [];
    for (let i = 0; i < init.length; i++) {
        let purpose = idxToPurpose[i];
        let k = keys[purpose].slice(0, init[i]);
        let p = Array(init[i]).fill(i + 1); // Use numeric value for purpose
        initKeys = initKeys.concat(k);
        initPurposes = initPurposes.concat(p);
    }

    // Deploy contract
    let contract = await Identity.new(
        initKeys,
        initPurposes,
        Array(initSum).fill(KeyType.ECDSA),
        {from: addr.manager[0]}
    );
    await measureTx(contract.transactionHash);

    // Check init
    let contractKeys = await contract.numKeys();
    contractKeys.should.be.bignumber.equal(initSum);

    console.debug(`Setup: ${getAndClearGas().toLocaleString()} gas (${initSum}/${totalSum} keys added)`.grey);

    return {
        contract,
        addr,
        keys
    }
}