use starknet::ContractAddress;
use super::types::{AgentStatus, KYCLevel, KycLevel, KycStatus};

#[derive(Copy, Drop, starknet::Event)]
pub struct MemberAdded {
    #[key]
    pub address: ContractAddress,
}

#[derive(Copy, Drop, starknet::Event)]
pub struct ContributionMade {
    #[key]
    pub round_id: u256,
    pub member: ContractAddress,
    pub amount: u256,
}

#[derive(Copy, Drop, starknet::Event)]
pub struct RoundDisbursed {
    #[key]
    pub round_id: u256,
    pub amount: u256,
    pub recipient: ContractAddress,
}

#[derive(Copy, Drop, starknet::Event)]
pub struct RoundCompleted {
    #[key]
    pub round_id: u256,
}

#[derive(Copy, Drop, starknet::Event)]
pub struct ContributionMissed {
    #[key]
    pub round_id: u256,
    pub member: ContractAddress,
}


// Standard ERC20 Transfer event
#[derive(Copy, Drop, starknet::Event)]
pub struct Transfer {
    #[key]
    pub from: ContractAddress, // Sender address
    #[key]
    pub to: ContractAddress, // Recipient address
    pub value: u256 // Amount transferred
}

// Standard ERC20 Approval event
#[derive(Copy, Drop, starknet::Event)]
pub struct Approval {
    #[key]
    pub owner: ContractAddress, // Token owner
    #[key]
    pub spender: ContractAddress, // Approved spender
    pub value: u256 // Approved amount
}

// Event emitted when a new currency is registered
#[derive(Copy, Drop, starknet::Event)]
pub struct CurrencyRegistered {
    #[key]
    pub currency: felt252, // Currency identifier
    pub admin: ContractAddress // Admin who registered it
}

// Event emitted when exchange rate is updated
#[derive(Copy, Drop, starknet::Event)]
pub struct ExchangeRateUpdated {
    #[key]
    pub from_currency: felt252, // Source currency
    #[key]
    pub to_currency: felt252, // Target currency
    pub rate: u256 // New exchange rate
}

// Event emitted when a token is converted between currencies
#[derive(Copy, Drop, starknet::Event)]
pub struct TokenConverted {
    #[key]
    pub user: ContractAddress, // User performing the conversion
    pub from_currency: felt252, // Source currency
    pub to_currency: felt252, // Target currency
    pub amount_in: u256, // Input amount
    pub amount_out: u256 // Output amount after conversion
}

// Event emitted when a new user is registered
#[derive(Copy, Drop, starknet::Event)]
pub struct UserRegistered {
    #[key]
    pub user_address: ContractAddress, // Registered user address
    pub email_hash: felt252, // Email hash for privacy
    // pub preferred_currency: felt252, // User's preferred currency
    pub registration_timestamp: u64 // Registration time
}

// Event emitted when user profile is updated
#[derive(Copy, Drop, starknet::Event)]
pub struct UserProfileUpdated {
    #[key]
    pub user_address: ContractAddress, // User address
    pub updated_fields: felt252 // Indication of what was updated
}

// Event emitted when user is deactivated
#[derive(Copy, Drop, starknet::Event)]
pub struct UserDeactivated {
    #[key]
    pub user_address: ContractAddress, // Deactivated user address
    pub admin: ContractAddress // Admin who performed the action
}

// Event emitted when user is reactivated
#[derive(Copy, Drop, starknet::Event)]
pub struct UserReactivated {
    #[key]
    pub user_address: ContractAddress, // Reactivated user address
    pub admin: ContractAddress // Admin who performed the action
}

// Event emitted when user KYC level is updated
#[derive(Copy, Drop, starknet::Event)]
pub struct KYCLevelUpdated {
    #[key]
    pub user_address: ContractAddress, // User address
    pub old_level: KYCLevel, // Previous KYC level
    pub new_level: KYCLevel, // New KYC level
    pub admin: ContractAddress // Admin who performed the update
}

#[derive(Copy, Drop, starknet::Event)]
pub struct KycStatusUpdated {
    #[key]
    pub user: ContractAddress,
    pub old_status: KycStatus,
    pub new_status: KycStatus,
    pub old_level: KycLevel,
    pub new_level: KycLevel,
}

#[derive(Copy, Drop, starknet::Event)]
pub struct KycEnforcementEnabled {
    pub enabled: bool,
    pub updated_by: ContractAddress,
}

// Transfer Administration Event Structs
#[derive(Copy, Drop, starknet::Event)]
pub struct TransferCreated {
    #[key]
    pub transfer_id: u256,
    #[key]
    pub sender: ContractAddress,
    #[key]
    pub recipient: ContractAddress,
    pub amount: u256,
    pub expires_at: u64,
}

#[derive(Copy, Drop, starknet::Event)]
pub struct TransferCancelled {
    #[key]
    pub transfer_id: u256,
    #[key]
    pub cancelled_by: ContractAddress,
    pub timestamp: u64,
    pub reason: felt252,
}

#[derive(Copy, Drop, starknet::Event)]
pub struct TransferCompleted {
    #[key]
    pub transfer_id: u256,
    #[key]
    pub completed_by: ContractAddress,
    pub timestamp: u64,
}

#[derive(Copy, Drop, starknet::Event)]
pub struct TransferPartialCompleted {
    #[key]
    pub transfer_id: u256,
    pub partial_amount: u256,
    pub total_amount: u256,
    pub timestamp: u64,
}

#[derive(Copy, Drop, starknet::Event)]
pub struct TransferExpired {
    #[key]
    pub transfer_id: u256,
    pub timestamp: u64,
}

#[derive(Copy, Drop, starknet::Event)]
pub struct CashOutRequested {
    #[key]
    pub transfer_id: u256,
    #[key]
    pub requested_by: ContractAddress,
    pub timestamp: u64,
}

#[derive(Copy, Drop, starknet::Event)]
pub struct CashOutCompleted {
    #[key]
    pub transfer_id: u256,
    #[key]
    pub agent: ContractAddress,
    pub timestamp: u64,
}

#[derive(Copy, Drop, starknet::Event)]
pub struct AgentAssigned {
    #[key]
    pub transfer_id: u256,
    #[key]
    pub agent: ContractAddress,
    #[key]
    pub assigned_by: ContractAddress,
    pub timestamp: u64,
}

#[derive(Copy, Drop, starknet::Event)]
pub struct AgentRegistered {
    #[key]
    pub agent_address: ContractAddress,
    pub name: felt252,
    pub commission_rate: u256,
    pub registered_by: ContractAddress,
    pub timestamp: u64,
}

#[derive(Copy, Drop, starknet::Event)]
pub struct AgentStatusUpdated {
    #[key]
    pub agent: ContractAddress,
    pub old_status: AgentStatus,
    pub new_status: AgentStatus,
    pub updated_by: ContractAddress,
    pub timestamp: u64,
}

#[derive(Copy, Drop, starknet::Event)]
pub struct TransferHistoryRecorded {
    #[key]
    pub transfer_id: u256,
    pub action: felt252,
    pub actor: ContractAddress,
    pub timestamp: u64,
}

// Event emitted when a new group is created
#[derive(Copy, Drop, starknet::Event)]
pub struct GroupCreated {
    #[key]
    pub group_id: u64, // Unique group ID
    pub creator: ContractAddress, // Address that created the group
    pub max_members: u8 // Configured size limit
}

// Event emitted when a user joins a group
#[derive(Copy, Drop, starknet::Event)]
pub struct MemberJoined {
    #[key]
    pub group_id: u64, // Group being joined
    #[key]
    pub member: ContractAddress // Address that joined
}

// Event emitted when tokens are minted
#[derive(Copy, Drop, starknet::Event)]
pub struct Minted {
    #[key]
    pub minter: ContractAddress, // Address that performed the minting
    #[key]
    pub recipient: ContractAddress, // Address that received the minted tokens
    pub amount: u256 // Amount of tokens minted
}

// Event emitted when tokens are burned
#[derive(Copy, Drop, starknet::Event)]
pub struct Burned {
    #[key]
    pub account: ContractAddress, // Address whose tokens were burned
    pub amount: u256 // Amount of tokens burned
}

// Event emitted when a new minter is added
#[derive(Copy, Drop, starknet::Event)]
pub struct MinterAdded {
    #[key]
    pub account: ContractAddress, // Address added as a minter
    #[key]
    pub added_by: ContractAddress // Admin who added the minter
}

// Event emitted when a minter is removed
#[derive(Copy, Drop, starknet::Event)]
pub struct MinterRemoved {
    #[key]
    pub account: ContractAddress, // Address removed from minters
    #[key]
    pub removed_by: ContractAddress // Admin who removed the minter
}

// Event emitted when the maximum supply is updated
#[derive(Copy, Drop, starknet::Event)]
pub struct MaxSupplyUpdated {
    pub new_max_supply: u256, // The new maximum supply
    #[key]
    pub updated_by: ContractAddress // Admin who updated the max supply
}

#[derive(Copy, Drop, starknet::Event)]
pub struct LoanRequested {
    pub id: u256,
    pub requester: ContractAddress,
    pub amount: u256,
    pub created_at: u64,
}

#[derive(Copy, Drop, starknet::Event)]
pub struct LoanApproved {
    pub id: u256,
    pub auth: ContractAddress,
    pub created_at: u64,
}

#[derive(Copy, Drop, starknet::Event)]
pub struct LoanReject {
    pub id: u256,
    pub auth: ContractAddress,
    pub created_at: u64,
}
