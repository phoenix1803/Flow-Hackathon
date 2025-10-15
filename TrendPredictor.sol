// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title TrendPredictor — lightweight on-chain "AI-like" trend predictor
/// @notice No imports, no constructor, no function parameters (no input fields).
///         Uses on-chain signals (timestamp, block number, contract balance)
///         and a tiny deterministic update rule as a stand-in for "AI".
contract TrendPredictor {
    // Owner (must be initialized once via initializeOwner())
    address public owner;

    // Small fixed-size model: 3 weights for 3 on-chain features.
    // These are signed integers so updates can go up or down.
    int256[3] public weights;

    // Timestamp when model was last updated
    uint256 public lastUpdated;

    // Keep a simple history counter of updates (for bookkeeping)
    uint256 public updateCount;

    // Prediction categories
    enum Trend {Down, Stable, Up}

    // Events
    event ModelUpdated(address indexed by, int256[3] newWeights, uint256 timestamp, uint256 updateCount);
    event Predicted(address indexed by, Trend trend, uint8 confidence, uint256 timestamp);

    // -------------------------
    // Initialization (no constructor)
    // -------------------------
    /// @notice Initialize the contract owner and a sane default model.
    /// @dev Must be called once after deployment. No inputs — caller becomes owner.
    function initializeOwner() external {
        require(owner == address(0), "Already initialized");
        owner = msg.sender;

        // Default sensible small weights
        weights[0] = int256(1);
        weights[1] = int256(0);
        weights[2] = int256(0);

        lastUpdated = block.timestamp;
        updateCount = 0;
    }

    // -------------------------
    // Access control
    // -------------------------
    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    // -------------------------
    // Internal feature extraction (no inputs)
    // -------------------------
    /// @dev Extract three simple numeric features from on-chain state.
    ///      All features derived without any external input.
    function _extractFeatures() internal view returns (int256 f0, int256 f1, int256 f2) {
        // Feature 0: last 3 digits of timestamp
        f0 = int256(uint256(block.timestamp) % 1000);

        // Feature 1: last 3 digits of block number
        f1 = int256(uint256(block.number) % 1000);

        // Feature 2: last 3 digits of contract balance (wei % 1000)
        f2 = int256(uint256(address(this).balance) % 1000);
    }

    // -------------------------
    // Tiny deterministic "learning" update (no inputs)
    // -------------------------
    /// @notice Update the internal model using current on-chain features.
    /// @dev Only owner can call. No input parameters as requested.
    ///      This uses a tiny "moving-target" update: weights move slowly toward features.
    function ingestOnChainData() external onlyOwner {
        (int256 f0, int256 f1, int256 f2) = _extractFeatures();

        // Very small learning rate implemented via integer math:
        // new_w = w + (feature - w) / 10  -> moves 1/10th of the distance toward feature
        weights[0] = weights[0] + (f0 - weights[0]) / 10;
        weights[1] = weights[1] + (f1 - weights[1]) / 10;
        weights[2] = weights[2] + (f2 - weights[2]) / 10;

        lastUpdated = block.timestamp;
        updateCount += 1;

        emit ModelUpdated(msg.sender, weights, lastUpdated, updateCount);
    }

    // -------------------------
    // Prediction (no inputs)
    // -------------------------
    /// @notice Produce a trend prediction and confidence using the current model and on-chain features.
    /// @dev No input parameters. Returns Trend enum and confidence 0-100.
    function predictTrend() external returns (Trend trend, uint8 confidence) {
        (int256 f0, int256 f1, int256 f2) = _extractFeatures();

        // Compute a simple score = dot(weights, features)
        // Note: features and weights are small, multiplication stays safe under 0.8.x overflow checks.
        int256 score = weights[0] * f0 + weights[1] * f1 + weights[2] * f2;

        // Map score to trend buckets
        // We first normalize score roughly by dividing by a scale factor.
        // The thresholds are chosen for demonstration; tweak if required.
        int256 scaled = score / 1000; // reduce magnitude

        if (scaled > 50) {
            trend = Trend.Up;
        } else if (scaled < -50) {
            trend = Trend.Down;
        } else {
            trend = Trend.Stable;
        }

        // Confidence: derive from absolute scaled value, capped to 100
        uint256 absScaled = uint256(scaled >= 0 ? scaled : -scaled);
        if (absScaled > 100) {
            absScaled = 100;
        }
        confidence = uint8(absScaled); // 0..100

        emit Predicted(msg.sender, trend, confidence, block.timestamp);
        return (trend, confidence);
    }

    // -------------------------
    // Read-only helpers (no inputs)
    // -------------------------
    /// @notice View a deterministic prediction without triggering events (pure view).
    function viewPrediction() external view returns (Trend trend, uint8 confidence) {
        (int256 f0, int256 f1, int256 f2) = _extractFeatures();
        int256 score = weights[0] * f0 + weights[1] * f1 + weights[2] * f2;
        int256 scaled = score / 1000;

        if (scaled > 50) {
            trend = Trend.Up;
        } else if (scaled < -50) {
            trend = Trend.Down;
        } else {
            trend = Trend.Stable;
        }

        uint256 absScaled = uint256(scaled >= 0 ? scaled : -scaled);
        if (absScaled > 100) {
            absScaled = 100;
        }
        confidence = uint8(absScaled);
        return (trend, confidence);
    }

    // -------------------------
    // Utility: withdraw small test funds (no inputs)
    // -------------------------
    /// @notice Owner can withdraw entire balance (no function parameters).
    function withdrawAll() external onlyOwner {
        payable(owner).transfer(address(this).balance);
    }

    // Allow contract to receive ETH so that feature f2 (balance) can change
    receive() external payable {}
    fallback() external payable {}
}
