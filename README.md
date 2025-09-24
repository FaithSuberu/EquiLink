EquiLink is a next-generation smart contract built on the Stacks blockchain that enables fractional ownership of real-world assets (RWAs) with dividends, loyalty incentives, NAV-based valuation, and governance-ready features.

This contract empowers investors to participate in tokenized vaults, earn dividends, reinvest automatically, and benefit from long-term loyalty rewards — all while ensuring compliance and security.

✨ Features

Fractional Minting & Redemption

Mint tokens with STX at NAV-based pricing.

Redeem tokens for STX equivalent.

Whitelist enforcement for investor compliance.

Dividends & Auto-Reinvest

Operators can distribute dividends to token holders.

Users can claim rewards or toggle auto-reinvest.

Loyalty multipliers incentivize long-term holding.

Net Asset Value (NAV) Tracking

NAV updated by oracles/auditors for accurate asset valuation.

Transparent valuation mechanism for trustless auditing.

Governance & Voting Weight

Token supply snapshots for DAO governance.

Governance integration for future decision-making.

Treasury Yield Deployment

Owner-controlled vault strategies.

Deploy STX into whitelisted DeFi protocols.

Security & Compliance

Multi-role access control (Owner, Operator, Auditor, Oracle).

Emergency circuit breaker to pause operations.

Configurable fees with treasury & operator splits.

📜 Smart Contract Functions
🔹 Public Functions

mint-tokens – Mint fractional tokens using STX.

redeem-tokens – Redeem tokens back to STX.

claim-dividends – Claim earned dividends.

toggle-auto-reinvest – Switch between reinvesting or claiming dividends.

update-nav – Update NAV by oracle or auditor.

distribute-dividends – Distribute vault profits to holders.

deploy-treasury-yield – Deploy vault funds to whitelisted strategies.

pause / unpause – Circuit breaker for emergency stops.

🔹 Read-Only Functions

get-balance – Check token balance of a user.

get-total-supply – Get circulating vault supply.

get-nav – View current NAV per token.

is-whitelisted – Verify if a user is compliance-approved.

get-role – Check if a principal is owner, operator, auditor, or oracle.



Run tests:

clarinet test

🧑‍🤝‍🧑 Roles & Access Control

Owner – Full administrative privileges.

Operator – Handles dividend distribution & treasury yield deployments.

Auditor – Validates NAV updates.

Oracle – Provides external NAV data.

🔒 Security Features

Circuit breaker for pausing operations.

Multi-role governance & audit trail.

Fee structure for transparent management.

📈 Future Improvements

DAO-based governance for parameter tuning.

DID integration for decentralized identity whitelisting.

Multi-oracle NAV aggregation for higher decentralization.
