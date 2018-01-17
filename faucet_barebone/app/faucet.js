// ~/DAPPS/faucet_barebone/app/faucet.js
if (typeof web3 !== 'undefined') {
    // Don't lose an existing provider, like Mist or Metamask
    web3 = new Web3(web3.currentProvider);
} else {
    // set the provider you want from Web3.providers
    web3 = new Web3(new Web3.providers.HttpProvider("http://localhost:8545"));
}
web3.eth.getCoinbase(function(err, coinbase) {
    if (err) {
        console.error(err);
    } else {
        console.log("Coinbase: " + coinbase);
    }
});

// Your deployed address changes every time you deploy.
const faucetAddress = "0xfc1ad69bb555c35c9a2cd58ab2142f4a380df135"; // <-- Put your own
const faucetContractFactory = web3.eth.contract(JSON.parse(faucetCompiled.contracts["faucet.sol:Faucet"].abi));
const faucetInstance = faucetContractFactory.at(faucetAddress);

function getBalance() {
    // Query eth for balance
    web3.eth.getBalance(faucetAddress, function(err, balance) {
        if (err) {
            console.error(err);
        } else {
            console.log("Contract balance: " + balance);
            var label = document.getElementsByTagName('label')[0];
            label.textContent += "/" + balance;
        }
    });

    // Query the contract directly
    faucetInstance.getBalance.call(function(err, balance) {
        if (err) {
            console.error(err);
        } else {
            console.log("Faucet balance: " + balance);
            var label = document.getElementsByTagName('label')[0];
            label.textContent += "/" + balance;
        }
    });
}
getBalance();

function topUp() {
    web3.eth.getCoinbase(function(err, coinbase) {
        if (err) {
            console.error(err);
        } else {
            web3.eth.sendTransaction({
                from: coinbase,
                to: faucetAddress,
                value: web3.toWei(1, "ether")
            }, function(err, txn) {
                if (err) {
                    console.error(err);
                } else {
                    console.log("topUp txn: " + txn);
                }
            });
        }
    });
}


function sendWei() {
    web3.eth.getCoinbase(function(err, coinbase) {
        if (err) {
            console.error(err);
        } else {
            web3.eth.getAccounts(function(err, accounts) {
                if (err) {
                    console.error(err);
                } else {
                    const targetAccount = accounts[1];
                    faucetInstance.sendWei(
                        targetAccount,
                        { from: coinbase },
                        function(err, txn) {
                            if (err) {
                                console.error(err);
                            } else {
                                console.log("sendWei txn: " + txn);
                            }
                        });
                }
            });
        }
    });
}