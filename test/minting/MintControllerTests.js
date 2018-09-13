var MintController = artifacts.require('minting/MintController');

var BigNumber = require('bignumber.js');
var tokenUtils = require('./../TokenTestUtils');
var checkVariables = tokenUtils.checkVariables;
var expectRevert = tokenUtils.expectRevert;

var mintUtils = require('./MintControllerUtils.js');
var AccountUtils = require('./../AccountUtils.js');
var A = AccountUtils.Accounts;
var initializeTokenWithProxyAndMintController = mintUtils.initializeTokenWithProxyAndMintController;
var checkMintControllerState = mintUtils.checkMintControllerState;

async function run_tests(newToken, accounts) {

    beforeEach('Make fresh token contract', async function () {
        rawToken = await newToken();
        var tokenConfig = await initializeTokenWithProxyAndMintController(rawToken);
        token = tokenConfig.token;
        mintController = tokenConfig.mintController;
    });

    it('should mint through mint controller', async function () {
        var amount = 5000;
        await mintController.configureController(A.controller1Account, A.minterAccount, {from: A.mintOwnerAccount});
        await mintController.configureMinter(amount, {from: A.controller1Account});
        customState = {
            'token': token.address,
            'controllers': {'controller1Account': A.minterAccount }
        }
        await checkMintControllerState([mintController], [customState]);

        await token.mint(A.arbitraryAccount, amount, {from: A.minterAccount});
        customVars = [
             { 'variable': 'masterMinter', 'expectedValue': mintController.address },
             { 'variable': 'isAccountMinter.minterAccount', 'expectedValue': true },
             { 'variable': 'balances.arbitraryAccount', 'expectedValue': new BigNumber(amount) },
             { 'variable': 'totalSupply', 'expectedValue': new BigNumber(amount)}
        ];
        await checkVariables([token], [customVars]);
    });

   it('initial state', async function () {
        customState = {
             'token': token.address,
        };

        await checkMintControllerState([mintController], [customState]);
    });

   it('only owner configures controller', async function () {
        await expectRevert(mintController.configureController(A.controller1Account, A.minterAccount, {from: A.minterAccount}));
   });

   it('sets token', async function () {
        await mintController.setToken(mintController.address, {from: A.mintOwnerAccount});
   });

   it('only owner sets token', async function () {
        await expectRevert(mintController.setToken(mintController.address, {from: A.minterAccount}));
   });

   it('remove minter', async function() {
        // create a minter
        var amount = 500;
        await mintController.configureController(A.controller1Account, A.minterAccount, {from: A.mintOwnerAccount});
        await mintController.configureMinter(amount, {from: A.controller1Account});
        customState = {
            'token': token.address,
            'controllers': {'controller1Account': A.minterAccount }
        }
        await checkMintControllerState([mintController], [customState]);
        customVars = [
             { 'variable': 'masterMinter', 'expectedValue': mintController.address },
             { 'variable': 'isAccountMinter.minterAccount', 'expectedValue': true },
             { 'variable': 'minterAllowance.minterAccount', 'expectedValue': new BigNumber(amount) },
        ];
        await checkVariables([token], [customVars]);

        // remove minter
        await mintController.removeMinter({from: A.controller1Account});
        await checkMintControllerState([mintController], [customState]);
        customVars = [
             { 'variable': 'masterMinter', 'expectedValue': mintController.address },
        ];
        await checkVariables([token], [customVars]);
   });

   it('only controller removes a minter', async function () {
        await expectRevert(mintController.removeMinter({from: A.controller1Account}));
   });

   it('only controller configures a minter', async function () {
        await expectRevert(mintController.configureMinter(0, {from: A.controller1Account}));
   });

   it('increment minter allowance', async function () {
        // configure controller & minter
        var amount = 500;
        await mintController.configureController(A.controller1Account, A.minterAccount, {from: A.mintOwnerAccount});
        await mintController.configureMinter(amount, {from: A.controller1Account});
        customState = {
            'token': token.address,
            'controllers': {'controller1Account': A.minterAccount }
        }
        await checkMintControllerState([mintController], [customState]);
        customVars = [
             { 'variable': 'masterMinter', 'expectedValue': mintController.address },
             { 'variable': 'isAccountMinter.minterAccount', 'expectedValue': true },
             { 'variable': 'minterAllowance.minterAccount', 'expectedValue': new BigNumber(amount) },
        ];
        await checkVariables([token], [customVars]);

        // increment minter allowance
        await mintController.incrementMinterAllowance(amount, {from: A.controller1Account});
        await checkMintControllerState([mintController], [customState]);
        customVars = [
             { 'variable': 'masterMinter', 'expectedValue': mintController.address },
             { 'variable': 'isAccountMinter.minterAccount', 'expectedValue': true },
             { 'variable': 'minterAllowance.minterAccount', 'expectedValue': new BigNumber(amount*2) },
        ];
        await checkVariables([token], [customVars]);
   });

   it('only controller increments allowance', async function () {
        await expectRevert(mintController.incrementMinterAllowance(0, {from: A.controller1Account}));
   });

   it('only active minters can have allowance incremented', async function () {
       // configure controller but not minter
        var amount = 500;
        await mintController.configureController(A.controller1Account, A.minterAccount, {from: A.mintOwnerAccount});
        customState = {
            'token': token.address,
            'controllers': {'controller1Account': A.minterAccount }
        }
        await checkMintControllerState([mintController], [customState]);
        customVars = [
             { 'variable': 'masterMinter', 'expectedValue': mintController.address },
        ];
        await checkVariables([token], [customVars]);

        // increment minter allowance
        await expectRevert(mintController.incrementMinterAllowance(amount, {from: A.controller1Account}));
   });


}

var testWrapper = require('./../TestWrapper');
testWrapper.execute('MintController_Tests', run_tests);

module.exports = {
  run_tests: run_tests,
}