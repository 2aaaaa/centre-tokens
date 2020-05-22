/**
 * SPDX-License-Identifier: MIT
 *
 * Copyright (c) CENTRE SECZ 2018-2020
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
 * SOFTWARE.
 */

pragma solidity 0.6.8;

import { AbstractFiatTokenV1 } from "../v1/AbstractFiatTokenV1.sol";
import { EIP712Domain } from "./EIP712Domain.sol";
import { EIP712 } from "../util/EIP712.sol";


/**
 * @title Gas Abstraction
 */
abstract contract GasAbstraction is AbstractFiatTokenV1, EIP712Domain {
    bytes32 public constant TRANSFER_WITH_AUTHORIZATION_TYPEHASH = 0x7c7c6cdb67a18743f49ec6fa9b35f50d52ed05cbed4cc592e13b44501c1a2267;
    // = keccak256("TransferWithAuthorization(address from,address to,uint256 value,uint256 validAfter,uint256 validBefore,bytes32 nonce)")
    bytes32 public constant APPROVE_WITH_AUTHORIZATION_TYPEHASH = 0x808c10407a796f3ef2c7ea38c0638ea9d2b8a1c63e3ca9e1f56ce84ae59df73c;
    // = keccak256("ApproveWithAuthorization(address owner,address spender,uint256 value,uint256 validAfter,uint256 validBefore,bytes32 nonce)")
    bytes32 public constant CANCEL_AUTHORIZATION_TYPEHASH = 0x158b0a9edf7a828aad02f63cd515c68ef2f50ba807396f6d12842833a1597429;
    // = keccak256("CancelAuthorization(address authorizer,bytes32 nonce)")

    enum AuthorizationState { Unused, Used, Canceled }

    /**
     * @dev authorizer address => nonce => authorization state
     */
    mapping(address => mapping(bytes32 => AuthorizationState)) private _authorizationStates;

    event AuthorizationUsed(address indexed authorizer, bytes32 indexed nonce);
    event AuthorizationCanceled(
        address indexed authorizer,
        bytes32 indexed nonce
    );

    /**
     * @notice Returns the state of an authorization
     * @param authorizer    Authorizer's address
     * @param nonce         Nonce of the authorization
     * @return Nonce state
     */
    function authorizationState(address authorizer, bytes32 nonce)
        external
        view
        returns (AuthorizationState)
    {
        return _authorizationStates[authorizer][nonce];
    }

    /**
     * @notice Verify a signed transfer authorization and execute if valid
     * @param from        Payer's address (Authorizer)
     * @param to          Payee's address
     * @param value       Amount to be transferred
     * @param validAfter  Earliest time this is valid, seconds since the epoch
     * @param validBefore Expiration time, secondss since the epoch
     * @param nonce       Unique nonce
     * @param v           v of the signature
     * @param r           r of the signature
     * @param s           s of the signature
     */
    function _transferWithAuthorization(
        address from,
        address to,
        uint256 value,
        uint256 validAfter,
        uint256 validBefore,
        bytes32 nonce,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) internal {
        _requireValidAuthorization(from, nonce, validAfter, validBefore);

        bytes memory data = abi.encode(
            TRANSFER_WITH_AUTHORIZATION_TYPEHASH,
            from,
            to,
            value,
            validAfter,
            validBefore,
            nonce
        );
        EIP712.verifySignature(DOMAIN_SEPARATOR, from, v, r, s, data);

        _transfer(from, to, value);
        _markAuthorizationAsUsed(from, nonce);
    }

    /**
     * @notice Verify a signed approval authorization and execute if valid
     * @param owner       Token owner's address (Authorizer)
     * @param spender     Spender's address
     * @param value       Amount of allowance
     * @param validAfter  Earliest time this is valid, seconds since the epoch
     * @param validBefore Expiration time, seconds since the epoch
     * @param nonce       Unique nonce
     * @param v           v of the signature
     * @param r           r of the signature
     * @param s           s of the signature
     */
    function _approveWithAuthorization(
        address owner,
        address spender,
        uint256 value,
        uint256 validAfter,
        uint256 validBefore,
        bytes32 nonce,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) internal {
        _requireValidAuthorization(owner, nonce, validAfter, validBefore);

        bytes memory data = abi.encode(
            APPROVE_WITH_AUTHORIZATION_TYPEHASH,
            owner,
            spender,
            value,
            validAfter,
            validBefore,
            nonce
        );
        EIP712.verifySignature(DOMAIN_SEPARATOR, owner, v, r, s, data);

        _approve(owner, spender, value);
        _markAuthorizationAsUsed(owner, nonce);
    }

    /**
     * @notice Attempt to cancel an authorization
     * @param authorizer    Authorizer's address
     * @param nonce         Nonce of the authorization
     * @param v             v of the signature
     * @param r             r of the signature
     * @param s             s of the signature
     */
    function _cancelAuthorization(
        address authorizer,
        bytes32 nonce,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) internal {
        _requireUnusedAuthorization(authorizer, nonce);

        bytes memory data = abi.encode(
            CANCEL_AUTHORIZATION_TYPEHASH,
            authorizer,
            nonce
        );
        EIP712.verifySignature(DOMAIN_SEPARATOR, authorizer, v, r, s, data);

        _authorizationStates[authorizer][nonce] = AuthorizationState.Canceled;
        emit AuthorizationCanceled(authorizer, nonce);
    }

    /**
     * @notice Check that an authorization is unused
     * @param authorizer    Authorizer's address
     * @param nonce         Nonce of the authorization
     */
    function _requireUnusedAuthorization(address authorizer, bytes32 nonce)
        private
        view
    {
        require(
            _authorizationStates[authorizer][nonce] ==
                AuthorizationState.Unused,
            "FiatTokenV2: authorization is used or canceled"
        );
    }

    /**
     * @notice Check that authorization is valid
     * @param authorizer    Authorizer's address
     * @param nonce         Nonce of the authorization
     * @param validAfter    Earliest time this is valid, seconds since the epoch
     * @param validBefore   Expiration time, seconds since the epoch
     */
    function _requireValidAuthorization(
        address authorizer,
        bytes32 nonce,
        uint256 validAfter,
        uint256 validBefore
    ) private view {
        require(
            now > validAfter,
            "FiatTokenV2: authorization is not yet valid"
        );
        require(now < validBefore, "FiatTokenV2: authorization is expired");
        _requireUnusedAuthorization(authorizer, nonce);
    }

    /**
     * @notice Mark an authorization as used
     * @param authorizer    Authorizer's address
     * @param nonce         Nonce of the authorization
     */
    function _markAuthorizationAsUsed(address authorizer, bytes32 nonce)
        private
    {
        _authorizationStates[authorizer][nonce] = AuthorizationState.Used;
        emit AuthorizationUsed(authorizer, nonce);
    }
}
