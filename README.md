# StarkRemit Contract

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

## Project Overview

**StarkRemit** is a comprehensive Cairo smart contract for cross-border remittances on StarkNet, featuring multi-currency support, KYC compliance, and advanced transfer administration capabilities.

This project leverages the scalability and low transaction costs of StarkNet L2 to provide secure, efficient, and compliant cross-border money transfers with comprehensive administrative controls.

**Key Features:**
- **ERC-20 Token Standard**: Full implementation with multi-currency support
- **User Registration & KYC**: Comprehensive user onboarding with multi-level verification
- **Transfer Administration**: Complete transfer lifecycle management with agent integration
- **Multi-Currency Support**: Handle multiple currencies with exchange rate integration
- **Agent Management**: Cash-out agent registration and authorization system
- **Transfer History**: Comprehensive tracking and searchable transaction history
- **Administrative Controls**: Admin functions for transfer and agent management
- **Event-Driven Architecture**: Real-time events for all administrative actions

---

## Transfer Administration Features ✅

The contract includes comprehensive transfer administration functionality:

### Transfer Lifecycle Management
- **Transfer Creation**: Create transfers with expiry times and metadata
- **Transfer Cancellation**: Cancel incomplete transfers with automatic refunds
- **Transfer Completion**: Mark transfers as completed with fund distribution
- **Partial Completion**: Support for partial transfer completion
- **Transfer Expiry**: Automatic handling of expired transfers with refunds

### Agent Integration
- **Agent Registration**: Register cash-out agents with regional and currency support
- **Agent Management**: Update agent status and manage agent lifecycle
- **Agent Authorization**: Verify agent permissions for specific transfers
- **Cash-Out Operations**: Agent-facilitated cash-out completion

### Transfer History & Tracking
- **Comprehensive History**: Track all transfer actions and status changes
- **Searchable Records**: Search history by actor, action, or transfer
- **Event Emission**: Real-time events for all administrative actions
- **Statistics Tracking**: Maintain transfer and agent statistics

---

## Setup Instructions

**Prerequisites:**
- [Scarb](https://docs.swmansion.com/scarb/) (Cairo package manager)
- [Starknet Foundry](https://foundry-rs.github.io/starknet-foundry/) (Testing framework)
- Git

**Installation:**

1. **Clone the repository:**
    ```bash
    git clone <your-repository-url>
    cd starkRemit_contract
    ```

2. **Install dependencies:**
    ```bash
    scarb build
    ```

3. **Run tests:**
    ```bash
   scarb test
    ```

---

## Available Scripts

- `scarb build`: Compiles the Cairo contract
- `scarb test`: Runs the test suite using Starknet Foundry
- `scarb fmt`: Formats the code

---

## Project Structure

```
starkRemit_contract/
├── Scarb.toml                    # Project manifest and dependencies
├── src/
│   ├── lib.cairo                 # Library entry point
│   ├── starkremit/
│   │   └── StarkRemit.cairo      # Main contract implementation
│   ├── base/
│   │   ├── types.cairo           # Data structures and enums
│   │   └── errors.cairo          # Error definitions
│   └── interfaces/
│       └── IStarkRemit.cairo     # Contract interface
├── tests/
│   ├── test_StarkRemit.cairo     # Transfer administration tests
│   ├── test_kyc.cairo            # KYC functionality tests
│   └── test_contract.cairo       # Basic contract tests
└── README.md                     # This file
```

---

## Key Data Structures

### Transfer Management
```cairo
struct Transfer {
    transfer_id: u256,
    sender: ContractAddress,
    recipient: ContractAddress,
    amount: u256,
    currency: felt252,
    status: TransferStatus,
    created_at: u64,
    updated_at: u64,
    expires_at: u64,
    assigned_agent: ContractAddress,
    partial_amount: u256,
    metadata: felt252,
}

enum TransferStatus {
    Pending,
    Completed,
    Cancelled,
    Expired,
    PartialComplete,
    CashOutRequested,
    CashOutCompleted,
}
```

### Agent Management
```cairo
struct Agent {
    agent_address: ContractAddress,
    name: felt252,
    status: AgentStatus,
    primary_currency: felt252,
    secondary_currency: felt252,
    primary_region: felt252,
    secondary_region: felt252,
    commission_rate: u256,
    completed_transactions: u256,
    total_volume: u256,
    registered_at: u64,
    last_active: u64,
    rating: u256,
}
```

### History Tracking
```cairo
struct TransferHistory {
    transfer_id: u256,
    action: felt252,
    actor: ContractAddress,
    timestamp: u64,
    previous_status: TransferStatus,
    new_status: TransferStatus,
    details: felt252,
}
```

---

## Transfer Administration API

### Transfer Operations
- `create_transfer()` - Create a new transfer
- `cancel_transfer()` - Cancel an existing transfer
- `complete_transfer()` - Mark transfer as completed
- `partial_complete_transfer()` - Partially complete a transfer
- `request_cash_out()` - Request cash-out for a transfer
- `complete_cash_out()` - Complete cash-out (agent only)

### Agent Management
- `register_agent()` - Register a new agent (admin only)
- `update_agent_status()` - Update agent status (admin only)
- `get_agent()` - Get agent details
- `is_agent_authorized()` - Check agent authorization

### Transfer Queries
- `get_transfer()` - Get transfer details
- `get_transfers_by_sender()` - Get transfers by sender
- `get_transfers_by_recipient()` - Get transfers by recipient
- `get_transfers_by_status()` - Get transfers by status
- `get_expired_transfers()` - Get expired transfers

### History & Statistics
- `get_transfer_history()` - Get transfer history
- `search_history_by_actor()` - Search history by actor
- `search_history_by_action()` - Search history by action
- `get_transfer_statistics()` - Get transfer statistics
- `get_agent_statistics()` - Get agent statistics

### Administrative Functions
- `assign_agent_to_transfer()` - Assign agent to transfer (admin only)
- `process_expired_transfers()` - Process expired transfers (admin only)

---

## Events

The contract emits comprehensive events for all transfer administration actions:

- `TransferCreated` - When a transfer is created
- `TransferCancelled` - When a transfer is cancelled
- `TransferCompleted` - When a transfer is completed
- `TransferPartialCompleted` - When a transfer is partially completed
- `TransferExpired` - When a transfer expires
- `CashOutRequested` - When cash-out is requested
- `CashOutCompleted` - When cash-out is completed
- `AgentAssigned` - When an agent is assigned
- `AgentRegistered` - When an agent is registered
- `AgentStatusUpdated` - When agent status is updated
- `TransferHistoryRecorded` - When history is recorded

---

## Testing

The contract includes comprehensive tests covering:
- Contract compilation and deployment
- Transfer lifecycle operations
- Agent management functionality
- History tracking and statistics
- KYC compliance and enforcement
- Error handling and edge cases

All tests pass successfully:
```bash
Tests: 20 passed, 0 failed, 0 skipped, 0 ignored, 0 filtered out
```

---

## Deployment

The contract requires the following constructor parameters:
- `admin`: Admin address with special privileges
- `name`: Token name
- `symbol`: Token symbol
- `initial_supply`: Initial token supply
- `base_currency`: Base currency identifier
- `oracle_address`: Oracle contract address for exchange rates

---

## Security Features

- **Access Control**: Admin-only functions for sensitive operations
- **KYC Integration**: Optional KYC enforcement for transfers
- **Transfer Limits**: Configurable transaction limits based on KYC level
- **Expiry Protection**: Automatic handling of expired transfers
- **Agent Authorization**: Strict agent verification for cash-out operations
- **Event Logging**: Comprehensive event emission for audit trails

---

## Performance Considerations

- **Efficient Storage**: Optimized storage patterns for gas efficiency
- **Batch Operations**: Support for processing multiple transfers
- **Indexed Queries**: Efficient querying by user, status, and region
- **Event-Driven**: Real-time event emission for external monitoring

---

## License

This project is licensed under the MIT License.