use starknet::ContractAddress;
use starknet::testing::{set_block_timestamp, set_caller_address};
use starkremit_contract::base::types::{MemberContribution, RoundData, RoundStatus};
use starkremit_contract::component::analytics::analytics_component::{AnalyticsComponent, Storage};
use starkremit_contract::component::analytics::{IAnalytics, IMainContractData};

// Mock implementation of IMainContractData for testing
#[starknet::interface]
trait IMockMainContract<TContractState> {
    fn get_round_data(self: @TContractState, round_id: u256) -> RoundData;
    fn get_member_contribution_data(
        self: @TContractState, round_id: u256, member: ContractAddress,
    ) -> MemberContribution;
    fn get_member_status(self: @TContractState, member: ContractAddress) -> bool;
    fn get_member_count(self: @TContractState) -> u32;
    fn get_member_by_index(self: @TContractState, index: u32) -> ContractAddress;
    fn get_round_ids(self: @TContractState) -> u256;
}

#[starknet::contract]
mod MockMainContract {
    use starknet::storage::Map;
    use super::*;

    #[storage]
    struct Storage {
        rounds: Map<u256, RoundData>,
        member_contributions: Map<(u256, ContractAddress), MemberContribution>,
        members: Map<ContractAddress, bool>,
        member_count: u32,
        member_by_index: Map<u32, ContractAddress>,
        round_ids: u256,
    }

    #[constructor]
    fn constructor(ref self: ContractState) {
        self.member_count.write(2);
        self.member_by_index.write(0, 0x123.try_into().unwrap());
        self.member_by_index.write(1, 0x456.try_into().unwrap());
        self.round_ids.write(1);

        // Setup test data
        let round_data = RoundData {
            deadline: 1000, completed_at: 0, status: RoundStatus::Active, total_contributions: 1000,
        };
        self.rounds.write(1, round_data);

        let member_contribution = MemberContribution {
            member: 0x123.try_into().unwrap(), amount: 500, contributed_at: 500,
        };
        self.member_contributions.write((1, 0x123.try_into().unwrap()), member_contribution);

        self.members.write(0x123.try_into().unwrap(), true);
        self.members.write(0x456.try_into().unwrap(), true);
    }

    impl MockMainContractImpl of IMockMainContract<ContractState> {
        fn get_round_data(self: @ContractState, round_id: u256) -> RoundData {
            self.rounds.read(round_id)
        }

        fn get_member_contribution_data(
            self: @ContractState, round_id: u256, member: ContractAddress,
        ) -> MemberContribution {
            self.member_contributions.read((round_id, member))
        }

        fn get_member_status(self: @ContractState, member: ContractAddress) -> bool {
            self.members.read(member)
        }

        fn get_member_count(self: @ContractState) -> u32 {
            self.member_count.read()
        }

        fn get_member_by_index(self: @ContractState, index: u32) -> ContractAddress {
            self.member_by_index.read(index)
        }

        fn get_round_ids(self: @ContractState) -> u256 {
            self.round_ids.read()
        }
    }
}

#[test]
fn test_analytics_initialization() {
    let mut state = AnalyticsComponent::contract_state_for_testing();
    let admin: ContractAddress = 0x123.try_into().unwrap();

    set_caller_address(admin);
    set_block_timestamp(1000);

    AnalyticsComponent::InternalImpl::initializer(ref state, admin);

    // Test that analytics is properly initialized
    let analytics = IAnalytics::get_contribution_analytics(@state);
    assert(analytics.total_rounds == 0, 'Should start with 0 rounds');
    assert(analytics.successful_rounds == 0, 'Should start with 0 successful rounds');
    assert(analytics.failed_rounds == 0, 'Should start with 0 failed rounds');
}

#[test]
fn test_member_analytics_update() {
    let mut state = AnalyticsComponent::contract_state_for_testing();
    let admin: ContractAddress = 0x123.try_into().unwrap();
    let member: ContractAddress = 0x456.try_into().unwrap();

    set_caller_address(admin);
    set_block_timestamp(1000);

    AnalyticsComponent::InternalImpl::initializer(ref state, admin);

    // Update member analytics
    AnalyticsComponent::InternalImpl::_update_member_analytics(
        ref state, member, true, // payment_made
        1000, // amount
        1 // round_id
    );

    // Check member analytics
    let member_analytics = IAnalytics::get_member_analytics(@state, member);
    assert(member_analytics.total_contributions == 1000, 'Total contributions should be 1000');
    assert(member_analytics.on_time_payments == 1, 'On time payments should be 1');
    assert(member_analytics.missed_payments == 0, 'Missed payments should be 0');
    assert(member_analytics.reliability_score == 100, 'Reliability score should be 100');
}

#[test]
fn test_round_performance_update() {
    let mut state = AnalyticsComponent::contract_state_for_testing();
    let admin: ContractAddress = 0x123.try_into().unwrap();

    set_caller_address(admin);
    set_block_timestamp(1000);

    AnalyticsComponent::InternalImpl::initializer(ref state, admin);

    // Update round metrics
    AnalyticsComponent::InternalImpl::_update_round_metrics(
        ref state,
        1, // round_id
        RoundStatus::Completed,
        1000, // total_contributions
        2 // participant_count
    );

    // Check round performance
    let round_performance = IAnalytics::get_round_performance(@state, 1);
    assert(round_performance.round_id == 1, 'Round ID should be 1');
    assert(round_performance.total_contributions == 1000, 'Total contributions should be 1000');
    assert(round_performance.participant_count == 2, 'Participant count should be 2');
}

#[test]
fn test_system_health_update() {
    let mut state = AnalyticsComponent::contract_state_for_testing();
    let admin: ContractAddress = 0x123.try_into().unwrap();

    set_caller_address(admin);
    set_block_timestamp(1000);

    AnalyticsComponent::InternalImpl::initializer(ref state, admin);

    // Update system health
    AnalyticsComponent::InternalImpl::_update_system_health(ref state);

    // Check system health
    let system_health = IAnalytics::get_system_health(@state);
    assert(system_health.last_health_check == 1000, 'Last health check should be 1000');
    assert(system_health.security_score > 0, 'Security score should be positive');
}

#[test]
fn test_financial_report_generation() {
    let mut state = AnalyticsComponent::contract_state_for_testing();
    let admin: ContractAddress = 0x123.try_into().unwrap();

    set_caller_address(admin);
    set_block_timestamp(1000);

    AnalyticsComponent::InternalImpl::initializer(ref state, admin);

    // Generate financial report
    let report = IAnalytics::generate_financial_report(@state, 0, 2000);

    // Check report
    assert(report.period_start == 0, 'Period start should be 0');
    assert(report.period_end == 2000, 'Period end should be 2000');
    assert(report.active_members == 0, 'Active members should be 0 initially');
}
