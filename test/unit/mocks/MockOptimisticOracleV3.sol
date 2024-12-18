// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import "@uma/core/contracts/optimistic-oracle-v3/interfaces/OptimisticOracleV3Interface.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract MockOptimisticOracleV3 is OptimisticOracleV3Interface {
    // Mapping to store assertions for testing
    mapping(bytes32 => Assertion) private _assertions;

    // Mapping to store assertion results
    mapping(bytes32 => bool) private _assertionResults;

    // Default values for testing
    bytes32 private _defaultIdentifier;
    IERC20 private _defaultCurrency;
    uint256 private _minimumBond;

    constructor(bytes32 defaultIdentifier, IERC20 currency, uint256 minBond) {
        _defaultIdentifier = defaultIdentifier;
        _defaultCurrency = currency;
        _minimumBond = minBond;
    }

    function defaultIdentifier() external view override returns (bytes32) {
        return _defaultIdentifier;
    }

    function assertTruth(
        bytes memory claim,
        address asserter,
        address callbackRecipient,
        address escalationManager,
        uint64 liveness,
        IERC20 currency,
        uint256 bond,
        bytes32 identifier,
        bytes32 domainId
    ) public override returns (bytes32 assertionId) {
        // Generate a unique assertion ID
        assertionId = keccak256(abi.encodePacked(claim, asserter, block.timestamp));

        // Create and store the assertion
        _assertions[assertionId] = Assertion({
            escalationManagerSettings: EscalationManagerSettings({
                arbitrateViaEscalationManager: false,
                discardOracle: false,
                validateDisputers: false,
                assertingCaller: msg.sender,
                escalationManager: escalationManager
            }),
            asserter: asserter,
            assertionTime: uint64(block.timestamp),
            settled: false,
            currency: currency,
            expirationTime: uint64(block.timestamp + liveness),
            settlementResolution: false,
            domainId: domainId,
            identifier: identifier,
            bond: bond,
            callbackRecipient: callbackRecipient,
            disputer: address(0)
        });

        // Emit event
        emit AssertionMade(
            assertionId,
            domainId,
            claim,
            asserter,
            callbackRecipient,
            escalationManager,
            msg.sender,
            uint64(block.timestamp + liveness),
            currency,
            bond,
            identifier
        );

        return assertionId;
    }

    function assertTruthWithDefaults(bytes memory claim, address asserter)
        external
        override
        returns (bytes32 assertionId)
    {
        return assertTruth(
            claim,
            asserter,
            address(0),
            address(0),
            7200, // 2 hours default liveness
            _defaultCurrency,
            _minimumBond,
            _defaultIdentifier,
            bytes32(0)
        );
    }

    // Mock method to set assertion result for testing
    function setAssertionResult(bytes32 assertionId, bool result) external {
        _assertions[assertionId].settled = true;
        _assertions[assertionId].settlementResolution = result;
        _assertionResults[assertionId] = result;
    }

    function settleAssertion(bytes32 assertionId) public override {
        require(_assertions[assertionId].expirationTime <= block.timestamp, "Cannot settle before expiration");
        _assertions[assertionId].settled = true;
    }

    function getAssertionResult(bytes32 assertionId) public view override returns (bool) {
        require(_assertions[assertionId].settled, "Assertion not settled");
        return _assertionResults[assertionId];
    }

    function settleAndGetAssertionResult(bytes32 assertionId) external override returns (bool) {
        settleAssertion(assertionId);
        return getAssertionResult(assertionId);
    }

    function getAssertion(bytes32 assertionId) external view override returns (Assertion memory) {
        return _assertions[assertionId];
    }

    function disputeAssertion(bytes32 assertionId, address disputer) external override {
        _assertions[assertionId].disputer = disputer;
        emit AssertionDisputed(assertionId, msg.sender, disputer);
    }

    function getMinimumBond(address /* currency */ ) external view override returns (uint256) {
        return _minimumBond;
    }

    function syncUmaParams(bytes32, /* identifier */ address /* currency */ ) external pure override {
        // No-op for mock
    }
}
