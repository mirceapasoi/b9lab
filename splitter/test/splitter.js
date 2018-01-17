const Splitter = artifacts.require("Splitter");
Promise = require("bluebird");
const getBalancePromise = Promise.promisify(web3.eth.getBalance);

contract("Splitter", (accounts) => {
    var instance;
    var owner = accounts[1];
    var alice = accounts[2];
    var bob = accounts[3];
    var carol = accounts[4];
    const oneEth = web3.toWei(1, "ether");
    const twoEth = web3.toWei(2, "ether");

    beforeEach(() => {
        return Splitter.new(alice, bob, carol, {from: owner}).then(_instance => {
            instance = _instance;
        })
    })

    it("should be owned by owner", () => {
        return instance.owner().then(_actualOwner => {
            assert.strictEqual(_actualOwner, owner, "contract is not owned by owner");
        });
    });

    it("should be killed by owner", () => {
        instance.kill({from: owner}).then(_result => {
            assert.isOk(_result);
        });
    });

    it("should not be killed by others", () => {
        instance.kill({from: alice}).catch(error => {
            assert.include(error.message, 'revert', "contract can't be killed");
        });
    });

    it("should receive ether", () => {
        instance.sendTransaction({from: owner, value: twoEth}).then(_result => {
            return instance.getBalance.call();
        }).then(_balance => {
            assert.equal(_balance, twoEth, "contract didn't receive 1 ether");
        });
    });

    it("split when alice sends", () => {
        let beforeA, afterA, beforeB, afterB, beforeC, afterC;
        instance.getAliceBalance.call().then(b => {
            beforeA = web3.fromWei(b, "ether" ).toNumber();
            return instance.getBobBalance.call();
        }).then(b => {
            beforeB = web3.fromWei(b, "ether" ).toNumber();
            return instance.getCarolBalance.call();
        }).then(b => {
            beforeC = web3.fromWei(b, "ether" ).toNumber();
            console.debug('Before: ', beforeA, beforeB, beforeC);
            assert.isAbove(beforeA, 0);
            assert.isAbove(beforeB, 0);
            assert.isAbove(beforeC, 0);
            return instance.sendTransaction({from: alice, value: twoEth});
        }).then(_result => {
            return instance.getAliceBalance.call()
        }).then(b => {
            afterA = web3.fromWei(b, "ether" ).toNumber();
            return instance.getBobBalance.call();
        }).then(b => {
            afterB = web3.fromWei(b, "ether" ).toNumber();
            return instance.getCarolBalance.call();
        }).then(b => {
            afterC = web3.fromWei(b, "ether" ).toNumber();
            console.debug('After: ', afterA, `(${afterA - beforeA})`,
                          afterB, `(${afterB - beforeB})`, afterC, `(${afterC - beforeC})`);
        });
    });

    it("split when others send", () => {
        let A = accounts[5], B = accounts[6], C = accounts[7];
        let beforeA, afterA, beforeB, afterB, beforeC, afterC;
        getBalancePromise(A).then(b => {
            beforeA = web3.fromWei(b, "ether" ).toNumber();
            return getBalancePromise(B);
        }).then(b => {
            beforeB = web3.fromWei(b, "ether" ).toNumber();
            return getBalancePromise(C);
        }).then(b => {
            beforeC = web3.fromWei(b, "ether" ).toNumber();
            console.debug('Before: ', beforeA, beforeB, beforeC);
            assert.isAbove(beforeA, 0);
            assert.isAbove(beforeB, 0);
            assert.isAbove(beforeC, 0);
            return instance.split(B, C, {from: A, value: oneEth});
        }).then(_result => {
            return getBalancePromise(A);
        }).then(b => {
            afterA = web3.fromWei(b, "ether" ).toNumber();
            return getBalancePromise(B);
        }).then(b => {
            afterB = web3.fromWei(b, "ether" ).toNumber();
            return getBalancePromise(C);
        }).then(b => {
            afterC = web3.fromWei(b, "ether" ).toNumber();
            console.debug('After: ', afterA, `(${afterA - beforeA})`,
                          afterB, `(${afterB - beforeB})`, afterC, `(${afterC - beforeC})`);
        });
    });
});