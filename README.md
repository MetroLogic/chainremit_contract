# starkRemit_contract

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Cairo](https://img.shields.io/badge/Cairo-1.x-orange.svg)](https://book.cairo-lang.org/)
[![Starknet](https://img.shields.io/badge/Starknet-L2-blue.svg)](https://starknet.io/)
[![Build Status](https://img.shields.io/badge/build-passing-brightgreen.svg)](#)

## Project Overview

**starkRemit_contract** is a Starknet smart contract designed for facilitating secure and efficient cross-border remittances with built-in escrow services and compliance features.

This project leverages the scalability and low transaction costs of Starknet L2 to solve the high-cost, slow settlement, and limited transparency issues plaguing traditional remittance services. By utilizing blockchain technology, we eliminate intermediaries, reduce fees from 6-10% to under 1%, and provide real-time settlement with full transaction transparency.

**Key Features:**
*   **Multi-Currency Support**: Send and receive payments in various ERC20 tokens with automatic conversion
*   **KYC Integration**: Built-in identity verification system with compliance checks for regulatory requirements
*   **Secure Escrow System**: Funds are locked in smart contract escrow until recipient confirmation or dispute resolution
*   **Real-time Exchange Rates**: Integration with Pragma Oracle for accurate, up-to-date currency conversion rates
*   **Dispute Resolution**: Automated arbitration system with appeal mechanisms for transaction conflicts
*   **Ultra-Low Fees**: Leverage Starknet's L2 efficiency for transaction costs under 0.5% of transfer amount
*   **Multi-signature Security**: Optional multi-sig approval for high-value transactions
*   **Compliance Monitoring**: Automatic AML/CFT screening and regulatory reporting capabilities

---

## Setup Instructions

Follow these steps to set up the project locally for development and testing.

**Prerequisites:**
*   [Scarb (Cairo package manager)](https://docs.swmansion.com/scarb/download.html) - v2.4.0 or higher
*   [Starknet Foundry (Testing framework)](https://foundry-rs.github.io/starknet-foundry/getting-started/installation.html) - v0.20.0 or higher
*   [Starknet Devnet (Local testnet)](https://github.com/0xSpaceShard/starknet-devnet-py) - v0.6.0 or higher
*   [Git](https://git-scm.com/downloads) - Latest stable version
*   [Node.js](https://nodejs.org/) - v18+ (for frontend integration scripts)

**Installation:**

1.  **Clone the repository:**
    ```bash
    git clone https://github.com/your-username/starkRemit_contract.git
    cd starkRemit_contract
    ```
2.  **Install Scarb dependencies:**
    ```bash
    scarb build
    ```
3.  **Configure environment variables:**
    ```bash
    cp .env.example .env
    # Edit .env with your configuration:
    # STARKNET_RPC_URL=https://starknet-goerli.g.alchemy.com/v2/your-api-key
    # ACCOUNT_ADDRESS=0x...
    # PRIVATE_KEY=0x...
    # PRAGMA_ORACLE_ADDRESS=0x...
    # DEFAULT_FEE_RATE=50  # 0.5% in basis points
    ```
4.  **Install additional tools:**
    ```bash
    # Install Starkli for contract interaction
    curl -L https://raw.githubusercontent.com/xJonathanLEI/starkli/master/install.sh | bash
    starkliup
    
    # Install Node.js dependencies for scripts
    npm install
    ```

**Running Locally:**

1.  **Start a local Starknet Devnet:**
    ```bash
    starknet-devnet --host 127.0.0.1 --port 5050 --seed 42 &
    ```
2.  **Compile the contract:**
    ```bash
    scarb build
    ```
3.  **Run tests:**
    ```bash
    snforge test --verbose
    ```
4.  **Deploy to local devnet:**
    ```bash
    ./scripts/deploy_local.sh
    ```

---

## Available Scripts

This project includes the following scripts to aid development:

*   `scarb build`: Compiles the Cairo contract and generates artifacts.
*   `snforge test`: Runs the complete test suite using Starknet Foundry.
*   `scarb fmt`: Formats all Cairo source code according to project standards.
*   **Local Deployment**: Deploys contract to local devnet with test configuration
    ```bash
    ./scripts/deploy_local.sh
    ```
*   **Testnet Deployment**: Deploys contract to Goerli or Sepolia testnet
    ```bash
    ./scripts/deploy_testnet.sh --network goerli
    ./scripts/deploy_testnet.sh --network sepolia
    ```
*   **Contract Interaction**: Utility scripts for common contract operations
    ```bash
    ./scripts/create_remittance.sh <recipient> <amount> <token_address>
    ./scripts/fund_remittance.sh <remittance_id>
    ./scripts/release_funds.sh <remittance_id>
    ```
*   **Oracle Setup**: Initialize and configure Pragma Oracle integration
    ```bash
    ./scripts/setup_oracle.sh
    ```
*   **Verification**: Verify deployed contracts on Starkscan
    ```bash
    ./scripts/verify_contract.sh <contract_address> <network>
    ```
*   **Load Testing**: Performance testing suite for high-volume scenarios
    ```bash
    npm run load-test
    ```

---

## Project Structure

```
/home/knights/Desktop/starkRemit_contract
├── Scarb.toml                    # Project manifest and dependencies
├── .env.example                  # Environment variables template
├── src/                          # Main contract source code
│   ├── lib.cairo                 # Contract entry point and module declarations
│   ├── core/                     # Core contract logic
│   │   ├── remittance.cairo      # Remittance creation and management
│   │   ├── escrow.cairo          # Escrow and fund locking mechanisms
│   │   ├── kyc.cairo             # KYC and compliance verification
│   │   └── dispute.cairo         # Dispute resolution system
│   ├── interfaces/               # Contract interfaces and traits
│   │   ├── IRemittance.cairo     # Main remittance interface
│   │   ├── IEscrow.cairo         # Escrow service interface
│   │   └── IOracle.cairo         # Price oracle interface
│   ├── utils/                    # Utility functions and helpers
│   │   ├── math.cairo            # Mathematical operations and validations
│   │   ├── access_control.cairo  # Role-based access control
│   │   └── events.cairo          # Event definitions and emissions
│   └── storage/                  # Storage definitions and mappings
│       ├── remittance_storage.cairo
│       └── user_storage.cairo
├── tests/                        # Comprehensive test suite
│   ├── unit/                     # Unit tests for individual functions
│   │   ├── test_remittance.cairo
│   │   ├── test_escrow.cairo
│   │   └── test_kyc.cairo
│   ├── integration/              # Integration tests for complete workflows
│   │   ├── test_full_remittance_flow.cairo
│   │   └── test_dispute_resolution.cairo
│   └── mocks/                    # Mock contracts for testing
│       ├── mock_erc20.cairo
│       └── mock_oracle.cairo
├── scripts/                      # Deployment and utility scripts
│   ├── deploy_local.sh
│   ├── deploy_testnet.sh
│   ├── create_remittance.sh
│   ├── fund_remittance.sh
│   ├── release_funds.sh
│   ├── setup_oracle.sh
│   └── verify_contract.sh
├── docs/                         # Additional documentation
│   ├── API.md                    # Detailed API documentation
│   ├── SECURITY.md               # Security considerations and audit reports
│   └── INTEGRATION.md            # Frontend integration guide
├── package.json                  # Node.js dependencies for scripts
└── README.md                     # This file
```

**Directory Descriptions:**
*   **`Scarb.toml`**: Defines project metadata, Cairo dependencies, and compilation settings.
*   **`src/core/`**: Contains the main business logic for remittance processing, escrow management, and compliance.
*   **`src/interfaces/`**: Defines contract interfaces following Cairo best practices for modularity.
*   **`src/utils/`**: Reusable utility functions for mathematical operations, access control, and event handling.
*   **`tests/`**: Comprehensive testing suite including unit tests, integration tests, and mock contracts.
*   **`scripts/`**: Shell and Node.js scripts for deployment, contract interaction, and maintenance tasks.
*   **`docs/`**: Extended documentation covering API details, security, and integration guides.

---

## Coding Conventions

*   **Language:** Cairo 1.x+ (Compatible with Cairo 2.4.0+)
*   **Formatting:** Use `scarb fmt` for consistent code style across all source files.
*   **Naming Conventions:**
    *   Contracts: `PascalCase` (e.g., `StarkRemit`, `EscrowManager`)
    *   Functions: `snake_case` (e.g., `create_remittance`, `release_funds`)
    *   Variables: `snake_case` (e.g., `sender_address`, `total_amount`)
    *   Structs/Enums: `PascalCase` (e.g., `RemittanceDetails`, `TransactionStatus`)
    *   Constants: `UPPER_SNAKE_CASE` (e.g., `MAX_REMITTANCE_AMOUNT`, `MIN_FEE_RATE`)
    *   Events: `PascalCase` (e.g., `RemittanceCreated`, `FundsReleased`)
    *   Storage Variables: `snake_case` (e.g., `remittances_by_id`, `user_kyc_status`)
*   **Documentation Standards:**
    *   Use `///` for documentation comments explaining functions, structs, and modules
    *   Include parameter descriptions, return value explanations, and usage examples
    *   Document all public interfaces with comprehensive examples
*   **Error Handling:**
    *   Use descriptive error messages with context
    *   Implement custom error types for different failure scenarios
    *   Use `assert!` for critical invariants and `panic_with_felt252` for custom error codes
    *   Prefer recoverable errors with proper Result types where applicable
*   **Security Practices:**
    *   Implement checks-effects-interactions pattern
    *   Use reentrancy guards for external calls
    *   Validate all inputs and state changes
    *   Follow principle of least privilege for access control
*   **Testing Standards:**
    *   Write unit tests for all public functions
    *   Include edge cases and boundary condition testing
    *   Test both success and failure scenarios
    *   Maintain minimum 85% code coverage
    *   Use descriptive test names following `test_function_name_condition_expected_result` pattern

---

## Deployment Process

**Prerequisites:**
*   Compiled contract artifacts in `target/dev/` directory
*   Funded Starknet account with sufficient ETH for deployment fees
*   RPC endpoint access for target network (Mainnet, Goerli, or Sepolia)
*   Deployment tools: Starkli v0.2.0+ or Starknet.js

**Network Configuration:**

| Network | RPC Endpoint | Chain ID | Status |
|---------|--------------|----------|---------|
| Mainnet | `https://starknet-mainnet.g.alchemy.com/v2/` | SN_MAIN | Production |
| Goerli  | `https://starknet-goerli.g.alchemy.com/v2/` | SN_GOERLI | Testnet |
| Sepolia | `https://starknet-sepolia.g.alchemy.com/v2/` | SN_SEPOLIA | Testnet |

**Deployment Steps (using Starkli):**

1.  **Set up Starkli account and keystore:**
    ```bash
    # Create account descriptor
    starkli account fetch <account_address> --rpc <rpc_url>
    
    # Create keystore (if not already done)
    starkli signer keystore from-key ~/.starkli-wallets/keystore.json
    ```

2.  **Declare the Contract Class:**
    ```bash
    starkli declare target/dev/starkRemit_contract_StarkRemit.contract_class.json \
        --network goerli \
        --account ~/.starkli-wallets/account.json \
        --keystore ~/.starkli-wallets/keystore.json \
        --compiler-version 2.4.0 \
        --max-fee 0.01
    
    # Save the returned class hash: 0x...
    ```

3.  **Deploy Contract Instance:**
    ```bash
    starkli deploy <class_hash> \
        <initial_owner_address> \
        <oracle_address> \
        <default_fee_rate> \
        --network goerli \
        --account ~/.starkli-wallets/account.json \
        --keystore ~/.starkli-wallets/keystore.json \
        --max-fee 0.05
    
    # Save the returned contract address: 0x...
    ```

**Constructor Parameters:**
*   `initial_owner`: Address that will have admin privileges (use your account address)
*   `oracle_address`: Pragma Oracle contract address for price feeds
*   `default_fee_rate`: Fee rate in basis points (e.g., 50 = 0.5%)

**Post-Deployment Configuration:**
```bash
# Set supported tokens
starkli invoke <contract_address> add_supported_token <token_address> --network goerli

# Configure KYC provider
starkli invoke <contract_address> set_kyc_provider <provider_address> --network goerli

# Set minimum/maximum remittance limits
starkli invoke <contract_address> set_limits <min_amount> <max_amount> --network goerli
```

**Automated Deployment:**
Use our deployment scripts for easier deployment:
```bash
# Deploy to testnet with configuration
./scripts/deploy_testnet.sh --network goerli --owner 0x... --oracle 0x...

# Deploy to mainnet (requires additional confirmations)
./scripts/deploy_mainnet.sh --owner 0x... --oracle 0x...
```

---

## Component Library Documentation (Contract Interface)

This section describes the main functions, data structures, and events exposed by the `starkRemit_contract`.

### Core Data Structures

**Structs:**

*   **`RemittanceDetails`**:
    ```cairo
    struct RemittanceDetails {
        id: u64,                           // Unique remittance identifier
        sender: ContractAddress,           // Address initiating the remittance
        recipient: ContractAddress,        // Intended recipient address
        amount: u256,                      // Amount in source token units
        source_token: ContractAddress,     // Source token contract address
        target_token: ContractAddress,     // Target token contract address
        exchange_rate: u256,               // Exchange rate at creation time
        fee_amount: u256,                  // Total fees charged
        status: RemittanceStatus,          // Current remittance status
        created_at: u64,                   // Block timestamp of creation
        funded_at: u64,                    // Block timestamp when funded
        released_at: u64,                  // Block timestamp when released
        expires_at: u64,                   // Expiration timestamp
        kyc_verified: bool,               // KYC verification status
        dispute_id: u64,                   // Associated dispute ID (if any)
    }
    ```

*   **`UserProfile`**:
    ```cairo
    struct UserProfile {
        address: ContractAddress,          // User's address
        kyc_level: KYCLevel,              // KYC verification level
        total_sent: u256,                  // Total amount sent lifetime
        total_received: u256,              // Total amount received lifetime
        reputation_score: u32,             // User reputation (0-1000)
        is_blocked: bool,                  // Account suspension status
        created_at: u64,                   // Registration timestamp
        last_activity: u64,                // Last transaction timestamp
    }
    ```

*   **`DisputeDetails`**:
    ```cairo
    struct DisputeDetails {
        id: u64,                           // Unique dispute identifier
        remittance_id: u64,               // Associated remittance ID
        initiator: ContractAddress,        // Address that raised the dispute
        reason: DisputeReason,            // Categorized dispute reason
        description: ByteArray,            // Detailed description
        evidence_hash: felt252,           // IPFS hash of evidence
        status: DisputeStatus,            // Current dispute status
        created_at: u64,                   // Dispute creation timestamp
        resolved_at: u64,                  // Resolution timestamp
        resolution: DisputeResolution,     // Final resolution decision
    }
    ```

**Enums:**

*   **`RemittanceStatus`**:
    ```cairo
    enum RemittanceStatus {
        Created,        // Remittance created but not funded
        Funded,         // Funds locked in escrow
        Released,       // Funds released to recipient
        Cancelled,      // Cancelled by sender (before funding)
        Disputed,       // Under dispute resolution
        Expired,        // Expired without completion
        Refunded,       // Funds returned to sender
    }
    ```

*   **`KYCLevel`**:
    ```cairo
    enum KYCLevel {
        None,           // No KYC verification
        Basic,          // Basic identity verification
        Enhanced,       // Enhanced due diligence
        Premium,        // Full institutional verification
    }
    ```

*   **`DisputeReason`**:
    ```cairo
    enum DisputeReason {
        PaymentNotReceived,     // Recipient claims non-receipt
        WrongAmount,           // Incorrect amount received
        UnauthorizedTx,        // Unauthorized transaction claim
        TechnicalIssue,        // Technical problem during transfer
        FraudSuspicion,        // Suspected fraudulent activity
        Other,                 // Other dispute reasons
    }
    ```

### External Functions

**Core Remittance Functions:**

*   **`fn create_remittance(ref self: ContractState, recipient: ContractAddress, amount: u256, source_token: ContractAddress, target_token: ContractAddress, expires_in: u64) -> u64`**:
    *   Creates a new remittance request with specified parameters.
    *   *Parameters:* 
        - `recipient`: Destination address for funds
        - `amount`: Amount to send in source token units
        - `source_token`: ERC20 token address for source currency
        - `target_token`: ERC20 token address for target currency
        - `expires_in`: Expiration time in seconds from now
    *   *Returns:* Unique remittance ID
    *   *Emits:* `RemittanceCreated` event
    *   *Requirements:* Valid addresses, amount > 0, tokens supported
    *   *Usage Example:* 
        ```bash
        starkli invoke <contract_address> create_remittance \
            0x1234...recipient 1000000000000000000 \
            0x5678...usdc 0x9abc...eth 86400
        ```

*   **`fn fund_remittance(ref self: ContractState, remittance_id: u64)`**:
    *   Locks funds in escrow for the specified remittance. Requires prior ERC20 approval.
    *   *Parameters:* `remittance_id`: ID of the remittance to fund
    *   *Emits:* `RemittanceFunded` event
    *   *Requirements:* Remittance exists, caller is sender, sufficient allowance
    *   *Usage Example:*
        ```bash
        # First approve token transfer
        starkli invoke <token_address> approve <contract_address> <amount>
        # Then fund the remittance
        starkli invoke <contract_address> fund_remittance 123
        ```

*   **`fn release_funds(ref self: ContractState, remittance_id: u64)`**:
    *   Releases escrowed funds to the recipient after validation.
    *   *Parameters:* `remittance_id`: ID of the remittance to complete
    *   *Emits:* `FundsReleased` event
    *   *Requirements:* Remittance funded, caller is recipient, not expired
    *   *Usage Example:*
        ```bash
        starkli invoke <contract_address> release_funds 123
        ```

*   **`fn cancel_remittance(ref self: ContractState, remittance_id: u64)`**:
    *   Cancels an unfunded remittance or refunds a funded one under specific conditions.
    *   *Parameters:* `remittance_id`: ID of the remittance to cancel
    *   *Emits:* `RemittanceCancelled` or `RemittanceRefunded` event
    *   *Requirements:* Caller is sender, valid cancellation conditions
    *   *Usage Example:*
        ```bash
        starkli invoke <contract_address> cancel_remittance 123
        ```

**Dispute Resolution Functions:**

*   **`fn raise_dispute(ref self: ContractState, remittance_id: u64, reason: DisputeReason, description: ByteArray, evidence_hash: felt252) -> u64`**:
    *   Initiates a dispute for a specific remittance.
    *   *Parameters:* Remittance ID, dispute reason, description, evidence hash
    *   *Returns:* Dispute ID
    *   *Emits:* `DisputeRaised` event
    *   *Usage Example:*
        ```bash
        starkli invoke <contract_address> raise_dispute 123 0 "Payment not received" 0x...
        ```

**
---

## License

This project is licensed under the MIT License - see the LICENSE file for details (if you add one).