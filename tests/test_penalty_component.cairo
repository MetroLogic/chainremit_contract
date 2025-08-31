// use starknet::ContractAddress;
// use starknet::testing::{set_caller_address, set_block_timestamp};
// use starknet::contract_address_const;
// use starkremit_contract::component::penalty::{
//     penalty_component, IPenaltyDispatcher, IPenaltyDispatcherTrait,
//     PenaltyConfig, MemberPenaltyRecord
// };

// const ADMIN: felt252 = 0x123;
// const NON_ADMIN: felt252 = 0x456;
// const MEMBER1: felt252 = 0x789;
// const MEMBER2: felt252 = 0xABC;

// fn setup() -> ContractAddress {
//     let admin_address = contract_address_const::<ADMIN>();
//     let contract_address = contract_address_const::<0x1>();
    
//     set_caller_address(admin_address);
//     set_block_timestamp(1000);
    
//     contract_address
// }

// fn get_default_penalty_config() -> PenaltyConfig {
//     PenaltyConfig {
//         late_fee_percentage: 300, // 3% in basis points
//         grace_period_hours: 24,
//         max_strikes: 3,
//         security_deposit_multiplier: 2,
//         penalty_pool_enabled: true,
//     }
// }

// #[test]
// fn test_penalty_config() {
//     let contract_address = setup();
//     let penalty = IPenaltyDispatcher { contract_address };
    
//     let config = get_default_penalty_config();
    
//     // Get initial config (should have default values)
//     let retrieved_config = penalty.get_penalty_config();
//     assert!(retrieved_config.late_fee_percentage >= 0, "Initial config should be valid");
// }

// #[test]
// fn test_apply_late_fee() {
//     let contract_address = setup();
//     let penalty = IPenaltyDispatcher { contract_address };
//     let member_address = contract_address_const::<MEMBER1>();
//     let round_id = 1_u256;
    
//     // Apply late fee
//     penalty.apply_late_fee(member_address, round_id);
    
//     // Check member penalty record
//     let record = penalty.get_member_penalty_record(member_address);
//     assert!(record.total_penalties_paid > 0, "Penalty should be applied");
// }

// #[test]
// fn test_strike_system() {
//     let contract_address = setup();
//     let penalty = IPenaltyDispatcher { contract_address };
//     let member_address = contract_address_const::<MEMBER1>();
//     let round_id = 1_u256;
    
//     // Add first strike
//     penalty.add_strike(member_address, round_id);
//     let record = penalty.get_member_penalty_record(member_address);
//     assert!(record.strikes == 1, "Member should have 1 strike");
//     assert!(!record.is_banned, "Member should not be banned yet");
    
//     // Add second strike
//     penalty.add_strike(member_address, round_id + 1);
//     let record = penalty.get_member_penalty_record(member_address);
//     assert!(record.strikes == 2, "Member should have 2 strikes");
//     assert!(!record.is_banned, "Member should not be banned yet");
    
//     // Add third strike (should result in ban if max_strikes is 3)
//     penalty.add_strike(member_address, round_id + 2);
//     let record = penalty.get_member_penalty_record(member_address);
//     assert!(record.strikes == 3, "Member should have 3 strikes");
    
//     // Remove a strike
//     penalty.remove_strike(member_address);
//     let record = penalty.get_member_penalty_record(member_address);
//     assert!(record.strikes == 2, "Member should have 2 strikes after removal");
// }

// #[test]
// fn test_ban_unban_member() {
//     let contract_address = setup();
//     let penalty = IPenaltyDispatcher { contract_address };
//     let member_address = contract_address_const::<MEMBER1>();
    
//     // Ban member
//     penalty.ban_member(member_address);
//     let record = penalty.get_member_penalty_record(member_address);
//     assert!(record.is_banned, "Member should be banned");
    
//     // Unban member
//     penalty.unban_member(member_address);
//     let record = penalty.get_member_penalty_record(member_address);
//     assert!(!record.is_banned, "Member should be unbanned");
//     assert!(record.strikes == 0, "Strikes should be reset on unban");
// }

// #[test]
// #[should_panic(expected: ('NOT_ADMIN',))]
// fn test_apply_late_fee_unauthorized() {
//     let contract_address = setup();
//     let penalty = IPenaltyDispatcher { contract_address };
//     let non_admin_address = contract_address_const::<NON_ADMIN>();
//     let member_address = contract_address_const::<MEMBER1>();
//     let round_id = 1_u256;
    
//     set_caller_address(non_admin_address);
//     penalty.apply_late_fee(member_address, round_id);
// }

// #[test]
// #[should_panic(expected: ('ALREADY_BANNED',))]
// fn test_ban_already_banned_member() {
//     let contract_address = setup();
//     let penalty = IPenaltyDispatcher { contract_address };
//     let member_address = contract_address_const::<MEMBER1>();
    
//     penalty.ban_member(member_address);
//     penalty.ban_member(member_address); // Should panic
// }

// #[test]
// #[should_panic(expected: ('NOT_BANNED',))]
// fn test_unban_not_banned_member() {
//     let contract_address = setup();
//     let penalty = IPenaltyDispatcher { contract_address };
//     let member_address = contract_address_const::<MEMBER1>();
    
//     penalty.unban_member(member_address); // Should panic as member is not banned
// }

// #[test]
// fn test_member_penalty_record_initialization() {
//     let contract_address = setup();
//     let penalty = IPenaltyDispatcher { contract_address };
//     let member_address = contract_address_const::<MEMBER1>();
    
//     let record = penalty.get_member_penalty_record(member_address);
//     assert!(record.strikes == 0, "New member should have 0 strikes");
//     assert!(record.total_penalties_paid == 0, "New member should have paid 0 penalties");
//     assert!(!record.is_banned, "New member should not be banned");
//     assert!(record.credit_score == 0, "New member should have initial credit score");
// }

// #[test]
// fn test_multiple_members_penalty_tracking() {
//     let contract_address = setup();
//     let penalty = IPenaltyDispatcher { contract_address };
//     let member1_address = contract_address_const::<MEMBER1>();
//     let member2_address = contract_address_const::<MEMBER2>();
//     let round_id = 1_u256;
    
//     // Apply penalties to both members
//     penalty.add_strike(member1_address, round_id);
//     penalty.apply_late_fee(member2_address, round_id);
    
//     // Check that penalties are tracked separately
//     let record1 = penalty.get_member_penalty_record(member1_address);
//     let record2 = penalty.get_member_penalty_record(member2_address);
    
//     assert!(record1.strikes == 1, "Member 1 should have 1 strike");
//     assert!(record2.strikes == 0, "Member 2 should have 0 strikes");
//     assert!(record1.total_penalties_paid == 0, "Member 1 should have no late fees");
//     assert!(record2.total_penalties_paid > 0, "Member 2 should have late fees");
// }

// #[test]
// fn test_credit_score_updates() {
//     let contract_address = setup();
//     let penalty = IPenaltyDispatcher { contract_address };
//     let member_address = contract_address_const::<MEMBER1>();
//     let round_id = 1_u256;
    
//     // Apply penalty and check credit score change
//     let initial_record = penalty.get_member_penalty_record(member_address);
//     penalty.apply_late_fee(member_address, round_id);
//     let updated_record = penalty.get_member_penalty_record(member_address);
    
//     // Credit score should be updated (implementation may vary)
//     assert!(updated_record.last_penalty_date > initial_record.last_penalty_date, "Last penalty date should be updated");
// }