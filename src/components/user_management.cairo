use starknet::ContractAddress;
use starknet::storage::{
    Map, StorageMapReadAccess, StorageMapWriteAccess, StoragePathEntry, StoragePointerReadAccess,
    StoragePointerWriteAccess,
};
use crate::base::events::user_management::*;
use crate::base::types::user_management::*;
#[starknet::interface]
pub trait IUserManagement<TContractState> {
    // User Registration Functions
    fn get_owner(self: @TContractState) -> ContractAddress;
    fn register_user(ref self: TContractState, registration_data: RegistrationRequest) -> bool;
    fn get_user_profile(self: @TContractState, user_address: ContractAddress) -> UserProfile;
    fn update_user_profile(ref self: TContractState, updated_profile: UserProfile) -> bool;
    fn is_user_registered(self: @TContractState, user_address: ContractAddress) -> bool;
    fn get_registration_status(
        self: @TContractState, user_address: ContractAddress,
    ) -> RegistrationStatus;
    fn get_total_users(self: @TContractState) -> u256;

    // Transfer Functions (User Operations)
    fn initiate_transfer(
        ref self: TContractState,
        recipient: ContractAddress,
        amount: u256,
        expires_at: u64,
        metadata: felt252,
    ) -> u256;
    fn create_transfer(
        ref self: TContractState,
        recipient: ContractAddress,
        amount: u256,
        expires_at: u64,
        metadata: felt252,
    ) -> u256;
    fn cancel_transfer(ref self: TContractState, transfer_id: u256) -> bool;
    fn complete_transfer(ref self: TContractState, transfer_id: u256) -> bool;
    fn partial_complete_transfer(
        ref self: TContractState, transfer_id: u256, partial_amount: u256,
    ) -> bool;
    fn request_cash_out(ref self: TContractState, transfer_id: u256) -> bool;
    fn get_transfer(self: @TContractState, transfer_id: u256) -> TransferData;
    fn get_transfers_by_sender(
        self: @TContractState, sender: ContractAddress, limit: u32, offset: u32,
    ) -> Array<TransferData>;
    fn get_transfers_by_recipient(
        self: @TContractState, recipient: ContractAddress, limit: u32, offset: u32,
    ) -> Array<TransferData>;
    fn get_transfers_by_status(
        self: @TContractState, status: TransferStatus, limit: u32, offset: u32,
    ) -> Array<TransferData>;
    fn get_expired_transfers(self: @TContractState, limit: u32, offset: u32) -> Array<TransferData>;

    // Transfer History Functions
    fn get_transfer_history(
        self: @TContractState, transfer_id: u256, limit: u32, offset: u32,
    ) -> Array<TransferHistory>;
    fn search_history_by_actor(
        self: @TContractState, actor: ContractAddress, limit: u32, offset: u32,
    ) -> Array<TransferHistory>;
    fn search_history_by_action(
        self: @TContractState, action: felt252, limit: u32, offset: u32,
    ) -> Array<TransferHistory>;
    fn get_transfer_statistics(self: @TContractState) -> (u256, u256, u256, u256);
}


#[starknet::component]
pub mod user_management_component {
    use super::*;

    #[storage]
    struct Storage {
        // ERC20 standard storage
        name: felt252, // Token name
        symbol: felt252, // Token symbol
        decimals: u8, // Token decimals (precision)
        total_supply: u256, // Total token supply
        balances: Map<ContractAddress, u256>, // User token balances
        allowances: Map<(ContractAddress, ContractAddress), u256>, // Spending allowances
        // User registration storage
        user_profiles: Map<ContractAddress, UserProfile>, // User profile data
        email_registry: Map<
            felt252, ContractAddress,
        >, // Email hash to address mapping for uniqueness
        phone_registry: Map<
            felt252, ContractAddress,
        >, // Phone hash to address mapping for uniqueness
        registration_status: Map<ContractAddress, RegistrationStatus>, // User registration status
        total_users: u256, // Total number of registered users
        registration_enabled: bool, // Whether registration is currently enabled
        // Transfer Administration storage
        transfers: Map<u256, TransferData>, // Transfer ID to Transfer mapping
        next_transfer_id: u256, // Counter for generating unique transfer IDs
        user_sent_transfers: Map<
            (ContractAddress, u32), u256,
        >, // User's sent transfers (user, index) -> transfer_id
        user_sent_count: Map<ContractAddress, u32>, // Count of transfers sent by user
        user_received_transfers: Map<
            (ContractAddress, u32), u256,
        >, // User's received transfers (user, index) -> transfer_id
        user_received_count: Map<ContractAddress, u32>, // Count of transfers received by user
        // Transfer History storage
        transfer_history: Map<
            (u256, u32), TransferHistory,
        >, // Transfer history (transfer_id, index) -> history
        transfer_history_count: Map<u256, u32>, // Count of history entries per transfer
        actor_history: Map<
            (ContractAddress, u32), (u256, u32),
        >, // Actor's history (actor, index) -> (transfer_id, history_index)
        actor_history_count: Map<ContractAddress, u32>, // Count of history entries by actor
        action_history: Map<
            (felt252, u32), (u256, u32),
        >, // Action history (action, index) -> (transfer_id, history_index)
        action_history_count: Map<felt252, u32>, // Count of history entries by action
        // Statistics storage
        total_transfers: u256, // Total number of transfers created
        total_completed_transfers: u256, // Total completed transfers
        total_cancelled_transfers: u256, // Total cancelled transfers
        total_expired_transfers: u256 // Total expired transfer
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        UserRegistered: UserRegistered, // Event for user registration
        UserProfileUpdated: UserProfileUpdated, // Event for profile updates
        UserDeactivated: UserDeactivated, // Event for user deactivation
        UserReactivated: UserReactivated, // Event for user reactivation
        Transfer: Transfer, // Standard ERC20 transfer event
        Approval: Approval, // Standard ERC20 approval event
        ExchangeRateUpdated: ExchangeRateUpdated, // Event for exchange rate updates
        TokenConverted: TokenConverted, // Event for token conversions
        TransferCreated: TransferCreated, // Event for transfer creation
        TransferCancelled: TransferCancelled, // Event for transfer cancellation
        TransferCompleted: TransferCompleted, // Event for transfer completion
        TransferPartialCompleted: TransferPartialCompleted, // Event for partial completion
        TransferExpired: TransferExpired, // Event for transfer expiry
        CashOutRequested: CashOutRequested, // Event for cash-out request
        CashOutCompleted: CashOutCompleted, // Event for cash-out completion
        TransferHistoryRecorded: TransferHistoryRecorded, // Event for history recording
        Minted: Minted,
        Burned: Burned,
    }

    #[embeddable_as(UserManagement)]
    impl UserManagementImpl<
        TContractState, +HasComponent<TContractState>,
    > of IUserManagement<ComponentState<TContractState>> {}

    #[generate_trait]
    pub impl InternalImpl<
        TContractState, +HasComponent<TContractState>,
    > of InternalTrait<TContractState> {}
}
