import assertRevert from 'zeppelin-solidity/test/helpers/assertRevert';
import { setupTest, assertKeyCount, Purpose, KeyType, ClaimType, Scheme } from './base';
import { printTestGas, printTotalGas, assertOkTx } from './util';

contract("ClaimManager", async (accounts) => {
    let contract, addr, keys;

    afterEach("print gas", printTestGas);
    after("all done", printTotalGas);

    const assertClaim = async (_claimType, _scheme, _issuer, _signature, _data, _uri) => {
        let claimId = await contract.getClaimId(_issuer, _claimType);
        const [claimType, scheme, issuer, signature, data, uri] = await contract.getClaim(claimId);

        claimType.should.be.bignumber.equal(_claimType);
        scheme.should.be.bignumber.equal(_scheme);
        assert.equal(issuer, _issuer);
        assert.equal(signature, _signature);
        if (_scheme == Scheme.RAW || _scheme == Scheme.URI) {
            assert.equal(web3.toAscii(data), _data);
            assert.equal(uri, _uri);
            if (_scheme == Scheme.URI) {
                assert.equal(_data, _uri);
            }
        } else {
            // TODO: Implement other scheme
            assert(false);
        }
    }

    const findClaimRequestId = (r) => {
        return r.logs.find(e => e.event == 'ClaimRequested').args.claimRequestId;
    }

    beforeEach("new contract", async () => {
        ({ contract, addr, keys } = await setupTest(accounts, 3, 4, 1, 1));
    });

    describe("ERC165", () => {
        it("supports ERC165, ERC725, ERC735", async () => {
            // ERC165
            assert.isFalse(await contract.supportsInterface("0xffffffff"));
            assert.isTrue(await contract.supportsInterface("0x01ffc9a7"));
            // ERC725
            assert.isTrue(await contract.supportsInterface("0x0c42c283"));
            // ERC735
            assert.isTrue(await contract.supportsInterface("0x10765379"));
        });
    })

    describe("addClaim", () => {
        it("can recover signature", async () => {
            let label = "test";
            // Claim hash
            let toSign = await contract.claimToSign(contract.address, ClaimType.LABEL, label);
            // Sign using eth_sign
            let signature = web3.eth.sign(addr.manager[0], toSign);
            // Recover address from signature
            let signedBy = await contract.signatureAddress(contract.address, ClaimType.LABEL, label, signature);
            assert.equal(signedBy, addr.manager[0]);
        });

        it("can add self-claim as manager", async () => {
            let label = "Mircea Pasoi";
            // Claim hash
            let toSign = await contract.claimToSign(contract.address, ClaimType.LABEL, label);
            // Sign using CLAIM_SIGNER_KEY
            let signature = web3.eth.sign(addr.claim[0], toSign);

            // Add self-claim as manager
            await assertOkTx(contract.addClaim(ClaimType.LABEL, Scheme.RAW, contract.address, signature, label, "", {from: addr.manager[0]}));

            // Check claim
            await assertClaim(ClaimType.LABEL, Scheme.RAW, contract.address, signature, label, "");
        });

        it("can add self-claim with manager approval", async () => {
            // Claim hash
            let uri = "https://twitter.com/mirceap";
            let toSign = await contract.claimToSign(contract.address, ClaimType.PROFILE, uri);
            // Sign using CLAIM_SIGNER_KEY
            let signature = web3.eth.sign(addr.claim[0], toSign);

            // Add self-claim with claim key
            let r = await assertOkTx(contract.addClaim(ClaimType.PROFILE, Scheme.URI, contract.address, signature, uri, uri, {from: addr.claim[0]}));
            let claimRequestId = findClaimRequestId(r);

            // Claim doesn't exist yet
            let claimId = await contract.getClaimId(contract.address, ClaimType.PROFILE);
            await assertRevert(contract.getClaim(claimId));

            // Approve
            await assertOkTx(contract.approve(claimRequestId, true, {from: addr.manager[0]}));

            // Check claim
            await assertClaim(ClaimType.PROFILE, Scheme.URI, contract.address, signature, uri, uri);
        });
    });
});
