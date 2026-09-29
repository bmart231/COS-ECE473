// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

// Import the ABDK Math library for fixed-point math functions (ln, exp, etc.)
import "abdk-libraries-solidity/ABDKMath64x64.sol";

contract LMSRPredictionMarket {
    using ABDKMath64x64 for int128;

    // Liquidity parameter for LMSR: higher = more liquidity, less price movement per trade
    uint256 public immutable b;
    address public owner;
    bool public marketResolved;
    bool public outcome; // true = Yes wins, false = No wins

    // Totals of shares purchased
    uint256 public totalYesShares;
    uint256 public totalNoShares;

    // Each user's Yes/No share balance
    mapping(address => uint256) public yesBalance;
    mapping(address => uint256) public noBalance;

    // The owner funds the contract at deployment to cover the LMSR worst-case loss (b * ln 2 ETH)
    constructor(uint256 _b) payable {
        b = _b;
        owner = msg.sender;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    // Calculate LMSR cost for a trade using exponential scoring rule.
    // Share quantities are whole shares; the returned cost is in wei (1 share pays 1 ETH).
    function calculateCost(
        uint256 qYesBefore,
        uint256 qNoBefore,
        uint256 qYesAfter,
        uint256 qNoAfter
    ) public view returns (uint256) {
        int128 b64 = ABDKMath64x64.fromUInt(b);

        // Convert quantities to fixed-point format and divide by b
        int128 qYes1 = ABDKMath64x64.fromUInt(qYesBefore).div(b64);
        int128 qNo1 = ABDKMath64x64.fromUInt(qNoBefore).div(b64);
        int128 qYes2 = ABDKMath64x64.fromUInt(qYesAfter).div(b64);
        int128 qNo2 = ABDKMath64x64.fromUInt(qNoAfter).div(b64);

        // Compute cost before and after the trade
        int128 cost1 = (qYes1.exp().add(qNo1.exp())).ln();
        int128 cost2 = (qYes2.exp().add(qNo2.exp())).ln();

        // Final cost = b * (cost2 - cost1), scaled to wei so fractional ETH is not truncated
        int128 costDelta = (cost2.sub(cost1)).mul(b64);
        return costDelta.mulu(1 ether);
    }

    // Buy Yes shares and pay Ether based on cost function
    function buyYes(uint256 amount) external payable {
        require(!marketResolved, "Market resolved");
        require(amount > 0, "Amount must be > 0");

        // Calculate cost of buying additional Yes shares
        uint256 cost = calculateCost(
            totalYesShares,
            totalNoShares,
            totalYesShares + amount,
            totalNoShares
        );

        require(msg.value >= cost, "Insufficient payment");

        // Update user balance and total shares
        yesBalance[msg.sender] += amount;
        totalYesShares += amount;

        // Refund any excess ETH sent
        uint256 refund = msg.value - cost;
        if (refund > 0) {
            (bool ok, ) = payable(msg.sender).call{value: refund}("");
            require(ok, "Refund failed");
        }
    }

    // Buy No shares and pay Ether based on cost function
    function buyNo(uint256 amount) external payable {
        require(!marketResolved, "Market resolved");
        require(amount > 0, "Amount must be > 0");

        // Calculate cost of buying additional No shares
        uint256 cost = calculateCost(
            totalYesShares,
            totalNoShares,
            totalYesShares,
            totalNoShares + amount
        );

        require(msg.value >= cost, "Insufficient payment");

        // Update user balance and total shares
        noBalance[msg.sender] += amount;
        totalNoShares += amount;

        // Refund any excess ETH sent
        uint256 refund = msg.value - cost;
        if (refund > 0) {
            (bool ok, ) = payable(msg.sender).call{value: refund}("");
            require(ok, "Refund failed");
        }
    }

    // Resolve the market with the actual outcome (only callable by owner)
    function resolveMarket(bool _outcome) external onlyOwner {
        require(!marketResolved, "Already resolved");
        marketResolved = true;
        outcome = _outcome;
    }

    // Redeem winning shares for ETH (1 share = 1 ETH payout)
    function redeem() external {
        require(marketResolved, "Market not resolved");

        uint256 shares;
        if (outcome) {
            // If "Yes" wins: pay out Yes shares, zero the balance before sending (prevents re-entrancy)
            shares = yesBalance[msg.sender];
            yesBalance[msg.sender] = 0;
        } else {
            // If "No" wins: pay out No shares, zero the balance before sending (prevents re-entrancy)
            shares = noBalance[msg.sender];
            noBalance[msg.sender] = 0;
        }

        require(shares > 0, "No winning shares");
        (bool ok, ) = payable(msg.sender).call{value: shares * 1 ether}("");
        require(ok, "Payout failed");
    }
}
