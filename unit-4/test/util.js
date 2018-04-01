// Big numbers
const BigNumber = web3.BigNumber;
require('chai').use(require('chai-bignumber')(BigNumber)).should();

// Gas tracking
let gasUsed = 0;

export const getAndClearGas = () => {
    let t = gasUsed;
    gasUsed = 0;
    return t;
}

export const measureTx = async (txHash) => {
    let receipt = await web3.eth.getTransactionReceipt(txHash);
    gasUsed += receipt.gasUsed;
}

export const assertOkTx = async promise => {
    let r = await promise;
    gasUsed += r.receipt.gasUsed;
    assert.isOk(r);
    return r;
}