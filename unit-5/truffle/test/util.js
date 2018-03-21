let gasUsed = 0;

export const getAndClearGas = () => {
    let t = gasUsed;
    gasUsed = 0;
    return t;
}
export const assertOkTx = async promise => {
    let r = await promise;
    gasUsed += r.receipt.gasUsed;
    assert.isOk(r);
    return r;
}