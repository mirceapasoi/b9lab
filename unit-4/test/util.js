const BigNumber = web3.BigNumber;
require('chai').use(require('chai-bignumber')(BigNumber)).should();

// Utility for error
let gasUsed = 0;

export const assertError = (e) => assert.include(e.message, 'revert', "contract din't throw");
export const getAndClearGas = () => {
    let t = gasUsed;
    gasUsed = 0;
    return t;
}
export const assertResult = (r) => {
    gasUsed += r.receipt.gasUsed;
    assert.isOk(r);
}
