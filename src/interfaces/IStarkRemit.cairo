use starknet::ContractAddress;
use starkremit_contract::base::types::*;

#[starknet::interface]
pub trait IStarkRemit<TContractState> {
    // Admin Role Management
    fn grant_admin_role(ref self: TContractState, admin: ContractAddress);

    // User Registration Functions
    // Get the contract owner address
    fn get_owner(self: @TContractState) -> ContractAddress;

    // Register a new user with the platform
    fn register_user(ref self: TContractState, registration_data: RegistrationRequest) -> bool;

    // Get user profile by address
    fn get_user_profile(self: @TContractState, user_address: ContractAddress) -> UserProfile;

    // Update user profile information
    fn update_user_profile(ref self: TContractState, updated_profile: UserProfile) -> bool;

    // Check if user is registered
    fn is_user_registered(self: @TContractState, user_address: ContractAddress) -> bool;

    // Get user registration status
    fn get_registration_status(
        self: @TContractState, user_address: ContractAddress,
    ) -> RegistrationStatus;

    // Update user KYC level (admin only)
    fn update_kyc_level(
        ref self: TContractState, user_address: ContractAddress, kyc_level: KYCLevel,
    ) -> bool;

    // Deactivate user account (admin only)
    fn deactivate_user(ref self: TContractState, user_address: ContractAddress) -> bool;

    // Reactivate user account (admin only)
    fn reactivate_user(ref self: TContractState, user_address: ContractAddress) -> bool;

    // Get total registered users count
    fn get_total_users(self: @TContractState) -> u256;

    // KYC Management Functions
    fn update_kyc_status(
        ref self: TContractState,
        user: ContractAddress,
        status: KycStatus,
        level: KycLevel,
        verification_hash: felt252,
        expires_at: u64,
    ) -> bool;

    fn get_kyc_status(self: @TContractState, user: ContractAddress) -> (KycStatus, KycLevel);

    fn is_kyc_valid(self: @TContractState, user: ContractAddress) -> bool;

    fn set_kyc_enforcement(ref self: TContractState, enabled: bool) -> bool;

    fn is_kyc_enforcement_enabled(self: @TContractState) -> bool;

    fn suspend_user_kyc(ref self: TContractState, user: ContractAddress) -> bool;

    fn reinstate_user_kyc(ref self: TContractState, user: ContractAddress) -> bool;

    // Transfer Administration Functions
    // Initiate a new transfer (enhanced version of create_transfer)
    fn initiate_transfer(
        ref self: TContractState,
        recipient: ContractAddress,
        amount: u256,
        expires_at: u64,
        metadata: felt252,
    ) -> u256;

    // Create a new transfer
    fn create_transfer(
        ref self: TContractState,
        recipient: ContractAddress,
        amount: u256,
        // currency: felt252,
        expires_at: u64,
        metadata: felt252,
    ) -> u256;

    // Cancel an existing transfer
    fn cancel_transfer(ref self: TContractState, transfer_id: u256) -> bool;

    // Complete a transfer (mark as completed)
    fn complete_transfer(ref self: TContractState, transfer_id: u256) -> bool;

    // Partially complete a transfer
    fn partial_complete_transfer(
        ref self: TContractState, transfer_id: u256, partial_amount: u256,
    ) -> bool;

    // Request cash-out for a transfer
    fn request_cash_out(ref self: TContractState, transfer_id: u256) -> bool;

    // Complete cash-out (agent only)
    fn complete_cash_out(ref self: TContractState, transfer_id: u256) -> bool;

    // Get transfer details
    fn get_transfer(self: @TContractState, transfer_id: u256) -> TransferData;

    // Get transfers by sender
    fn get_transfers_by_sender(
        self: @TContractState, sender: ContractAddress, limit: u32, offset: u32,
    ) -> Array<TransferData>;

    // Get transfers by recipient
    fn get_transfers_by_recipient(
        self: @TContractState, recipient: ContractAddress, limit: u32, offset: u32,
    ) -> Array<TransferData>;

    // Get transfers by status
    fn get_transfers_by_status(
        self: @TContractState, status: TransferStatus, limit: u32, offset: u32,
    ) -> Array<TransferData>;

    // Get expired transfers
    fn get_expired_transfers(self: @TContractState, limit: u32, offset: u32) -> Array<TransferData>;

    // Process expired transfers (admin only)
    fn process_expired_transfers(ref self: TContractState, limit: u32) -> u32;

    // Assign agent to transfer (admin only)
    fn assign_agent_to_transfer(
        ref self: TContractState, transfer_id: u256, agent: ContractAddress,
    ) -> bool;

    // Agent Management Functions
    // Register a new agent (admin only)
    fn register_agent(
        ref self: TContractState,
        agent_address: ContractAddress,
        name: felt252,
        // primary_currency: felt252,
        // secondary_currency: felt252,
        primary_region: felt252,
        secondary_region: felt252,
        commission_rate: u256,
    ) -> bool;

    // Update agent status (admin only)
    fn update_agent_status(
        ref self: TContractState, agent_address: ContractAddress, status: AgentStatus,
    ) -> bool;

    // Get agent details
    fn get_agent(self: @TContractState, agent_address: ContractAddress) -> Agent;

    // Get agents by status
    fn get_agents_by_status(
        self: @TContractState, status: AgentStatus, limit: u32, offset: u32,
    ) -> Array<Agent>;

    // Get agents by region
    fn get_agents_by_region(
        self: @TContractState, region: felt252, limit: u32, offset: u32,
    ) -> Array<Agent>;

    // Check if agent is authorized for transfer
    fn is_agent_authorized(
        self: @TContractState, agent: ContractAddress, transfer_id: u256,
    ) -> bool;

    // Transfer History Functions
    // Get transfer history
    fn get_transfer_history(
        self: @TContractState, transfer_id: u256, limit: u32, offset: u32,
    ) -> Array<TransferHistory>;

    // Search transfer history by actor
    fn search_history_by_actor(
        self: @TContractState, actor: ContractAddress, limit: u32, offset: u32,
    ) -> Array<TransferHistory>;

    // Search transfer history by action
    fn search_history_by_action(
        self: @TContractState, action: felt252, limit: u32, offset: u32,
    ) -> Array<TransferHistory>;

    // Get transfer statistics
    fn get_transfer_statistics(
        self: @TContractState,
    ) -> (u256, u256, u256, u256); // total, completed, cancelled, expired

    // Get agent statistics
    fn get_agent_statistics(
        self: @TContractState, agent: ContractAddress,
    ) -> (u256, u256, u256); // total_transfers, total_volume, rating

    // Savings Group Functions
    fn create_group(ref self: TContractState, max_members: u8) -> u64;

    fn join_group(ref self: TContractState, group_id: u64);

    fn view_group(self: @TContractState, group_id: u64) -> SavingsGroup;

    fn confirm_group_membership(self: @TContractState, group_id: u64) -> bool;

    //loan request
    fn requestLoan(ref self: TContractState, requester: ContractAddress, amount: u256) -> u256;

    // approve a loan
    fn approveLoan(ref self: TContractState, loan_id: u256) -> u256;

    // reject a loan
    fn rejectLoan(ref self: TContractState, loan_id: u256) -> u256;

    // Get loan request details
    fn getLoan(self: @TContractState, loan_id: u256) -> LoanRequest;

    // get loan count
    fn get_loan_count(self: @TContractState) -> u256;

    // if user has an active loan
    fn get_user_active_Loan(self: @TContractState, user: ContractAddress) -> bool;
    // check if user has an active loan request
    fn has_active_loan_request(self: @TContractState, user: ContractAddress) -> bool;

    fn repay_loan(ref self: TContractState, loan_id: u256, amount: u256) -> (u256, u256);
    // fn get_loan_details(self: @TContractState, loan_id: u256) -> (
    //     LoanRequest, u256, u64, u256, i64
    // );

    // Governance Functions
    // Admin Role Management
    fn assign_admin_role(ref self: TContractState, user: ContractAddress, role: GovRole) -> bool;
    fn revoke_admin_role(ref self: TContractState, user: ContractAddress) -> bool;
    fn get_admin_role(self: @TContractState, user: ContractAddress) -> GovRole;
    fn has_minimum_role(
        self: @TContractState, user: ContractAddress, required_role: GovRole,
    ) -> bool;

    // System Parameter Management
    fn set_system_parameter(ref self: TContractState, key: felt252, value: u256) -> bool;
    fn set_system_parameter_with_timelock(
        ref self: TContractState, key: felt252, value: u256,
    ) -> bool;
    fn get_system_parameter(self: @TContractState, key: felt252) -> u256;
    fn set_parameter_bounds(
        ref self: TContractState, key: felt252, bounds: ParameterBounds,
    ) -> bool;
    fn get_parameter_bounds(self: @TContractState, key: felt252) -> ParameterBounds;

    // Contract Registry
    fn register_contract(
        ref self: TContractState, name: felt252, contract_address: ContractAddress,
    ) -> bool;
    fn update_contract_address(
        ref self: TContractState, name: felt252, new_address: ContractAddress,
    ) -> bool;
    fn get_contract_address(self: @TContractState, name: felt252) -> ContractAddress;
    fn is_contract_registered(self: @TContractState, name: felt252) -> bool;

    // Timelock Management
    fn schedule_parameter_update(ref self: TContractState, key: felt252, value: u256) -> bool;
    fn execute_timelock_update(ref self: TContractState, key: felt252) -> bool;
    fn cancel_timelock_update(ref self: TContractState, key: felt252) -> bool;
    fn get_timelock_info(self: @TContractState, key: felt252) -> TimelockChange;

    // Fee Management
    fn update_fee(ref self: TContractState, fee_type: felt252, new_value: u256) -> bool;
    fn get_fee(self: @TContractState, fee_type: felt252) -> u256;

    // Parameter History
    fn get_parameter_history_count(self: @TContractState, key: felt252) -> u256;
    fn get_parameter_history(self: @TContractState, key: felt252, index: u256) -> ParameterHistory;

    // Utility Function
    fn get_timelock_duration(self: @TContractState) -> u64;

    // Emergency Pause Functions
    fn emergency_pause_contract(ref self: TContractState, reason: felt252);
    fn emergency_unpause_contract(ref self: TContractState);
    fn emergency_pause_with_metadata(ref self: TContractState, reason: felt252);
    fn emergency_unpause_with_metadata_clear(ref self: TContractState);
    fn emergency_set_pause_meta(ref self: TContractState, reason: felt252);
    fn emergency_set_ban(ref self: TContractState, member: ContractAddress, banned: bool);

    // Penalty Management Functions
    fn apply_late_fee(ref self: TContractState, member: ContractAddress, round_id: u256);
    fn add_strike(ref self: TContractState, member: ContractAddress, round_id: u256);
    fn remove_strike(ref self: TContractState, member: ContractAddress);
    fn ban_member(ref self: TContractState, member: ContractAddress);
    fn unban_member(ref self: TContractState, member: ContractAddress);
    fn distribute_penalty_pool(ref self: TContractState);

    // Auto-Schedule Management Functions
    fn setup_auto_schedule(ref self: TContractState, config: AutoScheduleConfig);
    fn maintain_rolling_schedule(ref self: TContractState);
    fn auto_activate_round(ref self: TContractState, round_id: u256);
    fn auto_complete_expired_rounds(ref self: TContractState);
    fn modify_schedule(ref self: TContractState, round_id: u256, new_deadline: u64);

    // Payment Flexibility Functions
    fn setup_auto_payment(
        ref self: TContractState,
        member: ContractAddress,
        token: ContractAddress,
        amount: u256,
        frequency: PaymentFrequency,
    );
    fn process_early_payment(
        ref self: TContractState,
        member: ContractAddress,
        round_id: u256,
        amount: u256,
    ) -> (u256, u256);
    fn extend_grace_period(
        ref self: TContractState,
        member: ContractAddress,
        extension_hours: u64,
    );
    fn add_supported_token(ref self: TContractState, token: ContractAddress);
    fn remove_supported_token(ref self: TContractState, token: ContractAddress);
    fn update_payment_config(ref self: TContractState, config: PaymentConfig);
    fn process_auto_payments(ref self: TContractState);
}
