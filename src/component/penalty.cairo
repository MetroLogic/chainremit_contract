use starknet::ContractAddress;
use starknet::get_block_timestamp;
use starknet::get_caller_address;
use core::array::{ArrayTrait, Array};
use core::serde::Serde;
use starkremit_contract::base::types::{PenaltyConfig, MemberPenaltyRecord, MemberContribution, RoundStatus, PenaltyEventRecord, DistributionData, MemberShare, PenaltyEventType, RoundData};

// Trait that the main contract must implement to provide data access
pub trait IMainContractData<TContractState> {
    fn get_member_contribution_data(self: @TContractState, round_id: u256, member: ContractAddress) -> MemberContribution;
    fn get_round_data(self: @TContractState, round_id: u256) -> RoundData;
    fn get_member_status(self: @TContractState, member: ContractAddress) -> bool;
    fn get_member_count(self: @TContractState) -> u32;
    fn get_round_ids(self: @TContractState) -> u256;
    fn get_member_by_index(self: @TContractState, index: u32) -> ContractAddress;
}


#[starknet::interface]
pub trait IPenalty<TContractState> {
    fn set_penalty_config(ref self: TContractState, config: PenaltyConfig);
    fn get_penalty_config(self: @TContractState) -> PenaltyConfig;
    fn get_member_penalty_record(self: @TContractState, member: ContractAddress) -> MemberPenaltyRecord;
    fn get_penalty_pool(self: @TContractState) -> u256;
    // Distribution calculation function
    fn calculate_distribution_data(self: @TContractState) -> DistributionData;
    // Reset penalty pool after distribution
    fn reset_penalty_pool(ref self: TContractState);
    // History functions
    fn get_penalty_history(self: @TContractState, member: ContractAddress, limit: u32, offset: u32) -> Array<PenaltyEventRecord>;
}


// Component events
#[derive(Drop, starknet::Event)]
pub struct LateFeeApplied {
    pub member: ContractAddress,
    pub round_id: u256,
    pub fee_amount: u256,
    pub contribution_amount: u256,
    pub timestamp: u64,
}

#[derive(Drop, starknet::Event)]
pub struct StrikeAdded {
    pub member: ContractAddress,
    pub round_id: u256,
    pub current_strikes: u32,
    pub timestamp: u64,
}

#[derive(Drop, starknet::Event)]
pub struct StrikeRemoved {
    pub member: ContractAddress,
    pub removed_by: ContractAddress,
    pub new_strikes: u32,
    pub timestamp: u64,
}


#[derive(Drop, starknet::Event)]
pub struct PenaltyConfigUpdated {
    pub old_config: PenaltyConfig,
    pub new_config: PenaltyConfig,
    pub updated_by: ContractAddress,
    pub timestamp: u64,
}

#[derive(Drop, starknet::Event)]
pub struct PenaltyPoolDistributed {
    pub total_amount: u256,
    pub recipient_count: u32,
    pub distribution_type: felt252,
    pub timestamp: u64,
}

#[derive(Drop, starknet::Event)]
pub struct GracePeriodExtended {
    pub member: ContractAddress,
    pub extension_hours: u64,
    pub total_extension: u64,
    pub extended_by: ContractAddress,
    pub timestamp: u64,
}

#[starknet::component]
pub mod penalty_component {
    use super::*;
    use starknet::storage::{
        Map, StoragePointerReadAccess, StoragePointerWriteAccess, StorageMapReadAccess, StorageMapWriteAccess,
    };
    use core::array::ArrayTrait;
    use starkremit_contract::base::errors::PenaltyComponentErrors;
    
    #[storage]
    pub struct Storage {
        penalty_config: PenaltyConfig,
        member_penalties: Map<ContractAddress, MemberPenaltyRecord>,
        penalty_pool: u256,
        penalty_history: Map<(ContractAddress, u32), PenaltyEventRecord>,
        penalty_history_count: Map<ContractAddress, u32>,
        grace_period_extensions: Map<ContractAddress, u64>,
        admin: ContractAddress,
    }
    
    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        LateFeeApplied: LateFeeApplied,
        StrikeAdded: StrikeAdded,
        StrikeRemoved: StrikeRemoved,
        PenaltyConfigUpdated: PenaltyConfigUpdated,
        PenaltyPoolDistributed: PenaltyPoolDistributed,
        GracePeriodExtended: GracePeriodExtended,
    }
    
    #[embeddable_as(Penalty)]
    impl PenaltyImpl<
        TContractState, +HasComponent<TContractState>, +IMainContractData<TContractState>,
    > of super::IPenalty<ComponentState<TContractState>> {
        
        fn set_penalty_config(ref self: ComponentState<TContractState>, config: PenaltyConfig) {
            self._assert_admin();
            
            let old_config = self.penalty_config.read();
            self.penalty_config.write(config);
            
            self.emit(Event::PenaltyConfigUpdated(PenaltyConfigUpdated {
                old_config,
                new_config: config,
                updated_by: get_caller_address(),
                timestamp: get_block_timestamp(),
            }));
        }
        
        fn get_penalty_config(self: @ComponentState<TContractState>) -> PenaltyConfig {
            self.penalty_config.read()
        }
        
        fn get_member_penalty_record(self: @ComponentState<TContractState>, member: ContractAddress) -> MemberPenaltyRecord {
            self.member_penalties.read(member)
        }
        
        fn get_penalty_pool(self: @ComponentState<TContractState>) -> u256 {
            self.penalty_pool.read()
        }
        
        fn reset_penalty_pool(ref self: ComponentState<TContractState>) {
            self._reset_penalty_pool();
        }

        fn calculate_distribution_data(self: @ComponentState<TContractState>) -> DistributionData {
            let contract_state = self.get_contract();
            let penalty_pool_amount = self.penalty_pool.read();
            
            if penalty_pool_amount == 0 {
                return DistributionData {
                    total_amount: 0,
                    member_shares: ArrayTrait::new(),
                    total_compliant_contributions: 0,
                };
            }
            
            let mut total_compliant_contributions = 0;
            let mut member_shares = ArrayTrait::new();
            
            // Calculate total contributions from compliant members
            let mut member_index = 0;
            let total_members = contract_state.get_member_count();
            
            while member_index < total_members {
                let member_address = contract_state.get_member_by_index(member_index);
                if contract_state.get_member_status(member_address) {
                    let penalty_record = self.member_penalties.read(member_address);
                    if !penalty_record.is_banned {
                        // Calculate member's total contribution across all rounds
                        let mut member_contribution = 0;
                        let mut round_id = 1;
                        while round_id <= contract_state.get_round_ids() {
                            let contribution = contract_state.get_member_contribution_data(round_id, member_address);
                            member_contribution += contribution.amount;
                            round_id += 1;
                        }
                        
                        total_compliant_contributions += member_contribution;
                        
                        if member_contribution > 0 {
                            let share = (member_contribution * penalty_pool_amount) / total_compliant_contributions;
                            if share > 0 {
                                member_shares.append(MemberShare {
                                    member: member_address,
                                    share,
                                    contribution: member_contribution,
                                });
                            }
                        }
                    }
                }
                member_index += 1;
            }
            
            DistributionData {
                total_amount: penalty_pool_amount,
                member_shares,
                total_compliant_contributions,
            }
        }
                
        fn get_penalty_history(
            self: @ComponentState<TContractState>, 
            member: ContractAddress, 
            limit: u32, 
            offset: u32
        ) -> Array<PenaltyEventRecord> {
            let mut history = ArrayTrait::new();
            let total_count = self.penalty_history_count.read(member);
            
            let mut i = offset;
            let mut count = 0;
            
            while i < total_count && count < limit {
                let event = self.penalty_history.read((member, i));
                history.append(event);
                count += 1;
                i += 1;
            }
            
            history
        }
    }
    

    
    #[generate_trait]
    pub impl InternalImpl<
        TContractState, +HasComponent<TContractState>, +IMainContractData<TContractState>,
    > of InternalTrait<TContractState> {
        
        fn initializer(ref self: ComponentState<TContractState>, admin: ContractAddress) {
            self.admin.write(admin);
            
            // Set default penalty configuration
            let default_config = PenaltyConfig {
                late_fee_percentage: 250, // 2.5% in basis points
                grace_period_hours: 48,   // 48 hours
                max_strikes: 2,           // 2 strikes before ban
                security_deposit_multiplier: 100000000000000000000, // 100 tokens
                penalty_pool_enabled: true,
            };
            self.penalty_config.write(default_config);
            
            // Initialize penalty pool
            self.penalty_pool.write(0);
        }
        
        fn _assert_admin(self: @ComponentState<TContractState>) {
            let admin = self.admin.read();
            assert(get_caller_address() == admin, PenaltyComponentErrors::NOT_ADMIN);
        }

        // Core penalty functions that need access to main contract data
        fn apply_late_fee(
            ref self: ComponentState<TContractState>, 
            member: ContractAddress, 
            round_id: u256
        ) {
            // Get main contract state to access member contributions and rounds
            let contract_state = self.get_contract();
            
            // Get penalty configuration and round data
            let penalty_config = self.penalty_config.read();
            let round = contract_state.get_round_data(round_id);
            let member_ext: u64 = self.grace_period_extensions.read(member);
            let total_grace_secs: u64 = penalty_config.grace_period_hours * 3600 + member_ext;
            assert(get_block_timestamp() > round.deadline + total_grace_secs, PenaltyComponentErrors::NOT_LATE);

            // If pool is disabled, do not collect late fees into pool
            assert(penalty_config.penalty_pool_enabled, PenaltyComponentErrors::PENALTY_POOL_DISABLED);
            
            // Get member contribution from main contract storage via trait
            let contribution = contract_state.get_member_contribution_data(round_id, member);
            assert(contribution.amount > 0, PenaltyComponentErrors::NO_CONTRIBUTION_FOR_ROUND);
            
            // Calculate late fee
            let late_fee = (contribution.amount * penalty_config.late_fee_percentage) / 10000;
            
            // Update penalty pool
            self._update_penalty_pool(late_fee);
            
            // Update member penalty record
            let mut penalty_record = self.member_penalties.read(member);
            penalty_record.total_penalties_paid += late_fee;
            penalty_record.last_penalty_date = get_block_timestamp();
            self.member_penalties.write(member, penalty_record);
            
            // Record penalty event
            self._record_penalty_event(member, round_id, PenaltyEventType::LateFee, late_fee);
            
            // Emit component event
            self.emit(Event::LateFeeApplied(LateFeeApplied {
                member,
                round_id,
                fee_amount: late_fee,
                contribution_amount: contribution.amount,
                timestamp: get_block_timestamp(),
            }));
        }

        fn add_strike(
            ref self: ComponentState<TContractState>, 
            member: ContractAddress, 
            round_id: u256
        ) {
            // Get penalty configuration from component storage
            let penalty_config = self.penalty_config.read();
            
            // Get current penalty record
            let mut penalty_record = self.member_penalties.read(member);
            penalty_record.strikes += 1;
            penalty_record.last_penalty_date = get_block_timestamp();
            
            // Check if member should be banned
            if penalty_record.strikes >= penalty_config.max_strikes {
                penalty_record.is_banned = true;
            }
            
            // Save updated penalty record
            self.member_penalties.write(member, penalty_record);
            
            // Record penalty event
            self._record_penalty_event(member, round_id, PenaltyEventType::Strike, 0);
            
            // Emit strike event
            self.emit(Event::StrikeAdded(StrikeAdded {
                member,
                round_id,
                current_strikes: penalty_record.strikes,
                timestamp: get_block_timestamp(),
            }));
        }

        fn remove_strike(
            ref self: ComponentState<TContractState>, 
            member: ContractAddress
        ) {
            // Get current penalty record
            let mut penalty_record = self.member_penalties.read(member);
            
            if penalty_record.strikes > 0 {
                penalty_record.strikes -= 1;
                
                // Check if member should be unbanned
                let penalty_config = self.penalty_config.read();
                if penalty_record.is_banned && penalty_record.strikes < penalty_config.max_strikes {
                    penalty_record.is_banned = false;
                    
                    // Note: Member re-addition is handled by the main contract
                    // The component only manages its own penalty state
                }
                
                // Save updated penalty record
                self.member_penalties.write(member, penalty_record);
                
                // Record penalty event
                self._record_penalty_event(member, 0, PenaltyEventType::StrikeRemoved, 0);
                
                // Emit event
                self.emit(Event::StrikeRemoved(StrikeRemoved {
                    member,
                    removed_by: get_caller_address(),
                    new_strikes: penalty_record.strikes,
                    timestamp: get_block_timestamp(),
                }));
            }
        }

        fn ban_member(
            ref self: ComponentState<TContractState>, 
            member: ContractAddress
        ) {
            // Get current penalty record
            let mut penalty_record = self.member_penalties.read(member);
            penalty_record.is_banned = true;
            penalty_record.strikes = self.penalty_config.read().max_strikes;
            
            // Save updated penalty record
            self.member_penalties.write(member, penalty_record);
            
            // Note: Member removal is handled by the main contract
            // The component only manages its own penalty state
            
            // Record penalty event
            self._record_penalty_event(member, 0, PenaltyEventType::Ban, 0);
        }

        fn unban_member(
            ref self: ComponentState<TContractState>, 
            member: ContractAddress
        ) {
            // Get current penalty record
            let mut penalty_record = self.member_penalties.read(member);
            penalty_record.is_banned = false;
            penalty_record.strikes = 0;
            
            // Save updated penalty record
            self.member_penalties.write(member, penalty_record);
            
            // Note: Member re-addition is handled by the main contract
            // The component only manages its own penalty state
            
            // Record penalty event
            self._record_penalty_event(member, 0, PenaltyEventType::Unban, 0);
        }
        
        fn _reset_penalty_pool(ref self: ComponentState<TContractState>) {
            self.penalty_pool.write(0);
        }
        
        
        fn _record_penalty_event(
            ref self: ComponentState<TContractState>,
            member: ContractAddress,
            round_id: u256,
            event_type: PenaltyEventType,
            amount: u256,
        ) {
            let history_count = self.penalty_history_count.read(member);
            let event = PenaltyEventRecord {
                member,
                round_id,
                event_type,
                amount,
                timestamp: get_block_timestamp(),
                admin: get_caller_address(),
            };
            
            self.penalty_history.write((member, history_count), event);
            self.penalty_history_count.write(member, history_count + 1);
        }

        fn _update_penalty_pool(ref self: ComponentState<TContractState>, amount: u256) {
            let current_pool = self.penalty_pool.read();
            self.penalty_pool.write(current_pool + amount);
        }
    }
}
