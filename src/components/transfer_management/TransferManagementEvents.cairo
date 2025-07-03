use starknet::ContractAddress;
/// @notice Emitted when a transfer of tokens occurs.
/// @param from The address sending the tokens.
/// @param to The address receiving the tokens.
/// @param value The amount of tokens transferred.
/// #[derive(Copy, Drop, starknet::Event)]
pub struct Transfer {
    #[key]
    pub from: ContractAddress,
    #[key]
    pub to: ContractAddress,
    pub value: u256,
}


/// @notice Emitted when an approval is set by an owner to a spender.
/// @param owner The address granting approval.
/// @param spender The address receiving approval.
/// @param value The amount approved.
#[derive(Copy, Drop, starknet::Event)]
pub struct Approval {
    #[key]
    pub owner: ContractAddress,
    #[key]
    pub spender: ContractAddress,
    pub value: u256,
}


/// @notice Emitted when a new transfer is created.
/// @param transfer_id The unique identifier for the transfer.
/// @param sender The address initiating the transfer.
/// @param recipient The address receiving the transfer.
/// @param amount The amount to be transferred.
/// @param expires_at The expiration timestamp for the transfer.
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

/// @notice Emitted when a transfer is cancelled.
/// @param transfer_id The unique identifier for the transfer.
/// @param cancelled_by The address that cancelled the transfer.
/// @param timestamp The time when the transfer was cancelled.
/// @param reason The reason for cancellation.
#[derive(Copy, Drop, starknet::Event)]
pub struct TransferCancelled {
    #[key]
    pub transfer_id: u256,
    #[key]
    pub cancelled_by: ContractAddress,
    pub timestamp: u64,
    pub reason: felt252,
}

/// @notice Emitted when a transfer is completed.
/// @param transfer_id The unique identifier for the transfer.
/// @param completed_by The address that completed the transfer.
/// @param timestamp The time when the transfer was completed.
#[derive(Copy, Drop, starknet::Event)]
pub struct TransferCompleted {
    #[key]
    pub transfer_id: u256,
    #[key]
    pub completed_by: ContractAddress,
    pub timestamp: u64,
}


/// @notice Emitted when a transfer is partially completed.
/// @param transfer_id The unique identifier for the transfer.
/// @param partial_amount The amount that was partially completed.
/// @param total_amount The total amount of the transfer.
/// @param timestamp The time when the partial completion occurred.
#[derive(Copy, Drop, starknet::Event)]
pub struct TransferPartialCompleted {
    #[key]
    pub transfer_id: u256,
    pub partial_amount: u256,
    pub total_amount: u256,
    pub timestamp: u64,
}

/// @notice Emitted when a transfer expires.
/// @param transfer_id The unique identifier for the transfer.
/// @param timestamp The time when the transfer expired.
#[derive(Copy, Drop, starknet::Event)]
pub struct TransferExpired {
    #[key]
    pub transfer_id: u256,
    pub timestamp: u64,
}

/// @notice Emitted when a cash out is requested for a transfer.
/// @param transfer_id The unique identifier for the transfer.
/// @param requested_by The address requesting the cash out.
/// @param timestamp The time when the cash out was requested.
#[derive(Copy, Drop, starknet::Event)]
pub struct CashOutRequested {
    #[key]
    pub transfer_id: u256,
    #[key]
    pub requested_by: ContractAddress,
    pub timestamp: u64,
}


/// @notice Emitted when a cash out is completed for a transfer.
/// @param transfer_id The unique identifier for the transfer.
/// @param agent The address of the agent completing the cash out.
/// @param timestamp The time when the cash out was completed.
#[derive(Copy, Drop, starknet::Event)]
pub struct CashOutCompleted {
    #[key]
    pub transfer_id: u256,
    #[key]
    pub agent: ContractAddress,
    pub timestamp: u64,
}

/// @notice Emitted when a transfer history record is created.
/// @param transfer_id The unique identifier for the transfer.
/// @param action The action performed (as a felt252 value).
/// @param actor The address performing the action.
/// @param timestamp The time when the action was recorded.
#[derive(Copy, Drop, starknet::Event)]
pub struct TransferHistoryRecorded {
    #[key]
    pub transfer_id: u256,
    pub action: felt252,
    pub actor: ContractAddress,
    pub timestamp: u64,
}


/// @notice Emitted when a new currency is registered.
/// @param currency The identifier of the registered currency.
/// @param admin The address of the admin who registered the currency.
#[derive(Copy, Drop, starknet::Event)]
pub struct CurrencyRegistered {
    #[key]
    pub currency: felt252,
    pub admin: ContractAddress,
}

/// @notice Emitted when an exchange rate between two currencies is updated.
/// @param from_currency The source currency identifier.
/// @param to_currency The target currency identifier.
/// @param rate The new exchange rate.
#[derive(Copy, Drop, starknet::Event)]
pub struct ExchangeRateUpdated {
    #[key]
    pub from_currency: felt252,
    #[key]
    pub to_currency: felt252,
    pub rate: u256,
}

/// @notice Emitted when a user converts tokens from one currency to another.
/// @param user The address of the user performing the conversion.
/// @param from_currency The source currency identifier.
/// @param to_currency The target currency identifier.
/// @param amount_in The amount of source currency converted.
/// @param amount_out The amount of target currency received.
#[derive(Copy, Drop, starknet::Event)]
pub struct TokenConverted {
    #[key]
    pub user: ContractAddress,
    pub from_currency: felt252,
    pub to_currency: felt252,
    pub amount_in: u256,
    pub amount_out: u256,
}

/// @notice Emitted when tokens are minted.
/// @param minter The address that performed the minting.
/// @param recipient The address receiving the minted tokens.
/// @param amount The amount of tokens minted.
#[derive(Copy, Drop, starknet::Event)]
pub struct Minted {
    #[key]
    pub minter: ContractAddress,
    #[key]
    pub recipient: ContractAddress,
    pub amount: u256,
}

/// @notice Emitted when tokens are burned.
/// @param account The address whose tokens were burned.
/// @param amount The amount of tokens burned.
#[derive(Copy, Drop, starknet::Event)]
pub struct Burned {
    #[key]
    pub account: ContractAddress,
    pub amount: u256,
}

/// @notice Emitted when a new minter is added.
/// @param account The address that was granted minter rights.
/// @param added_by The address that added the minter.
#[derive(Copy, Drop, starknet::Event)]
pub struct MinterAdded {
    #[key]
    pub account: ContractAddress,
    #[key]
    pub added_by: ContractAddress,
}

/// @notice Emitted when a minter is removed.
/// @param account The address whose minter rights were revoked.
/// @param removed_by The address that removed the minter.
#[derive(Copy, Drop, starknet::Event)]
pub struct MinterRemoved {
    #[key]
    pub account: ContractAddress,
    #[key]
    pub removed_by: ContractAddress,
}

/// @notice Emitted when the maximum token supply is updated.
/// @param new_max_supply The new maximum supply value.
/// @param updated_by The address that updated the max supply.
#[derive(Copy, Drop, starknet::Event)]
pub struct MaxSupplyUpdated {
    pub new_max_supply: u256,
    #[key]
    pub updated_by: ContractAddress,
}
