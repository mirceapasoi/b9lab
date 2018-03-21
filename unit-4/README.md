# Splitter

## Low Difficulty

* Did you check proper msg.value or did you read from a cheaply misleading amount parameter? YES
* Did you check the bool return value of address.send()? YES
* Did you throw when it fails? YES
* Did you create methods to get balance, when the facility is already there with web3? NO

## Medium Difficulty

* Did you pass proper beneficiary addresses as part of the constructor? Instead of using a setter afterwards. YES
* Did you check for empty addresses? Which may happen on badly formatted transactions. YES
* Did you split msg.value and forgot that odd values may leave 1 wei in the contract balance? NO
* Did you close the fallback function? YES
* Did you provide a kill / pause switch? YES
* Do your events make it possible to reconstruct the whole contract state? YES
* Did you mark functions as payable only when necessary? YES
* Did you write any test? Do they cover illegal actions? YES
* Would your tests fail if your Solidity code was incorrect? YES

## High Difficulty

* Did you send (a.k.a. push) the funds instead of letting the beneficiaries withdraw (a.k.a. pull) the funds? YES
* If you pushed the funds, did you cover a potential reentrance? I.e. did you update all your state before making the transfer? N/A

---

# Rock Paper Scissors

* Beside the shared points with Splitter. OK

## Medium Difficulty

* Did you make sure that Bob cannot spy on Alice's move before he plays? YES

## High Difficulty

* Did you let secret moves be reused? YES 👎

---

# Remittance

* Beside the shared points with Rock Paper Scissors. OK

## Medium Difficulty

* Did you store supposedly secret information in the contract? NO
* Did you understand a private statement a bit too literally? NO
* Did you send passwords in the clear too early? NO
* Did you cover the game theoretic elements right? YES
* Did you prevent sabotage / overwriting? YES
* Did you keep off-chain what can be kept off-chain? YES

## High Difficulty

* Did you let passwords be reused? NO
* Did you think about miners possibly front-running your users with a competing transaction? YES