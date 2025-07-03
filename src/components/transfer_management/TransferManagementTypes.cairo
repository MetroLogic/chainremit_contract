use starknet::ContractAddress;

#[derive(Copy, Drop, Serde, starknet::Store)]
pub struct TransactionLimits {
    pub daily_limit: u256,
    pub single_tx_limit: u256,
}

/// Transfer status for tracking transfer lifecycle
#[derive(Copy, Drop, Serde, starknet::Store, PartialEq)]
pub enum TransferStatus {
    #[default]
    None,
    Pending,
    Completed,
    Cancelled,
    Expired,
    PartialComplete,
    CashOutRequested,
    CashOutCompleted,
}

/// Transfer data structure for managing transfers
#[derive(Copy, Drop, Serde, starknet::Store)]
pub struct TransferData {
    pub transfer_id: u256,
    pub sender: ContractAddress,
    pub recipient: ContractAddress,
    pub amount: u256,
    pub status: TransferStatus,
    pub created_at: u64,
    pub updated_at: u64,
    pub expires_at: u64,
    pub assigned_agent: ContractAddress,
    pub partial_amount: u256,
    pub metadata: felt252,
}

/// Transfer history entry for comprehensive tracking
#[derive(Copy, Drop, Serde, starknet::Store)]
pub struct TransferHistory {
    pub transfer_id: u256,
    pub action: felt252,
    pub actor: ContractAddress,
    pub timestamp: u64,
    pub previous_status: TransferStatus,
    pub new_status: TransferStatus,
    pub details: felt252,
}
