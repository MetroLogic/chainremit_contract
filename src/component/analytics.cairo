use starknet::ContractAddress;
use starkremit_contract::base::types::{
    ContributionAnalytics, FinancialReport, MemberAnalytics, MemberContribution, RoundData,
    RoundPerformanceMetrics, RoundStatus, RoundSuccessStatus, SystemHealthMetrics,
};

// Trait that the main contract must implement to provide data access
pub trait IMainContractData<TContractState> {
    fn get_round_data(self: @TContractState, round_id: u256) -> RoundData;
    fn get_member_contribution_data(
        self: @TContractState, round_id: u256, member: ContractAddress,
    ) -> MemberContribution;
    fn get_member_status(self: @TContractState, member: ContractAddress) -> bool;
    fn get_member_count(self: @TContractState) -> u32;
    fn get_member_by_index(self: @TContractState, index: u32) -> ContractAddress;
    fn get_round_ids(self: @TContractState) -> u256;
}

#[starknet::interface]
pub trait IAnalytics<TContractState> {
    // Configuration and query functions (simple operations)
    fn get_contribution_analytics(self: @TContractState) -> ContributionAnalytics;
    fn get_member_analytics(self: @TContractState, member: ContractAddress) -> MemberAnalytics;
    fn get_round_performance(self: @TContractState, round_id: u256) -> RoundPerformanceMetrics;
    fn get_system_health(self: @TContractState) -> SystemHealthMetrics;
    fn generate_financial_report(
        self: @TContractState, period_start: u64, period_end: u64,
    ) -> FinancialReport;

    // Utility functions (simple operations)
    fn get_member_reliability_score(self: @TContractState, member: ContractAddress) -> u8;
    fn get_round_success_rate(self: @TContractState, round_id: u256) -> u8;
    fn get_total_system_value(self: @TContractState) -> u256;
}


#[starknet::component]
pub mod analytics_component {
    use core::array::ArrayTrait;
    use starknet::storage::{
        Map, StorageMapReadAccess, StorageMapWriteAccess, StoragePointerReadAccess,
        StoragePointerWriteAccess,
    };
    use starknet::{ContractAddress, get_block_timestamp, get_caller_address};
    use starkremit_contract::base::errors::AnalyticsComponentErrors;
    use super::*;

    #[storage]
    pub struct Storage {
        contribution_analytics: ContributionAnalytics,
        member_analytics: Map<ContractAddress, MemberAnalytics>,
        round_metrics: Map<u256, RoundPerformanceMetrics>,
        financial_reports: Map<u64, FinancialReport>, // timestamp -> report
        system_metrics: SystemHealthMetrics,
        admin: ContractAddress,
        last_update_timestamp: u64,
        total_system_value: u256,
        analytics_enabled: bool,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        AnalyticsUpdated: AnalyticsUpdated,
        MemberAnalyticsUpdated: MemberAnalyticsUpdated,
        RoundMetricsUpdated: RoundMetricsUpdated,
        FinancialReportGenerated: FinancialReportGenerated,
        SystemHealthUpdated: SystemHealthUpdated,
        AnalyticsConfigUpdated: AnalyticsConfigUpdated,
    }

    #[derive(Drop, starknet::Event)]
    pub struct AnalyticsUpdated {
        admin: ContractAddress,
        timestamp: u64,
    }

    #[derive(Drop, starknet::Event)]
    pub struct MemberAnalyticsUpdated {
        member: ContractAddress,
        reliability_score: u8,
        timestamp: u64,
    }

    #[derive(Drop, starknet::Event)]
    pub struct RoundMetricsUpdated {
        round_id: u256,
        completion_rate: u8,
        timestamp: u64,
    }

    #[derive(Drop, starknet::Event)]
    pub struct FinancialReportGenerated {
        period_start: u64,
        period_end: u64,
        total_contributions: u256,
        timestamp: u64,
    }

    #[derive(Drop, starknet::Event)]
    pub struct SystemHealthUpdated {
        security_score: u8,
        uptime_percentage: u8,
        timestamp: u64,
    }

    #[derive(Drop, starknet::Event)]
    pub struct AnalyticsConfigUpdated {
        admin: ContractAddress,
        enabled: bool,
        timestamp: u64,
    }

    #[embeddable_as(Analytics)]
    pub impl AnalyticsImpl<
        TContractState, +HasComponent<TContractState>, +IMainContractData<TContractState>,
    > of super::IAnalytics<ComponentState<TContractState>> {
        fn get_contribution_analytics(
            self: @ComponentState<TContractState>,
        ) -> ContributionAnalytics {
            self.contribution_analytics.read()
        }

        fn get_member_analytics(
            self: @ComponentState<TContractState>, member: ContractAddress,
        ) -> MemberAnalytics {
            self.member_analytics.read(member)
        }

        fn get_round_performance(
            self: @ComponentState<TContractState>, round_id: u256,
        ) -> RoundPerformanceMetrics {
            self.round_metrics.read(round_id)
        }

        fn get_system_health(self: @ComponentState<TContractState>) -> SystemHealthMetrics {
            self.system_metrics.read()
        }

        fn generate_financial_report(
            self: @ComponentState<TContractState>, period_start: u64, period_end: u64,
        ) -> FinancialReport {
            self._generate_financial_report(period_start, period_end)
        }

        fn get_member_reliability_score(
            self: @ComponentState<TContractState>, member: ContractAddress,
        ) -> u8 {
            let analytics = self.member_analytics.read(member);
            analytics.reliability_score
        }

        fn get_round_success_rate(self: @ComponentState<TContractState>, round_id: u256) -> u8 {
            let metrics = self.round_metrics.read(round_id);
            metrics.completion_rate
        }

        fn get_total_system_value(self: @ComponentState<TContractState>) -> u256 {
            self.total_system_value.read()
        }
    }

    #[generate_trait]
    pub impl InternalImpl<
        TContractState, +HasComponent<TContractState>, +IMainContractData<TContractState>,
    > of InternalTrait<TContractState> {
        fn initializer(ref self: ComponentState<TContractState>, admin: ContractAddress) {
            self.admin.write(admin);
            self.analytics_enabled.write(true);
            self.last_update_timestamp.write(get_block_timestamp());

            // Initialize default analytics
            let default_analytics = ContributionAnalytics {
                total_rounds: 0,
                successful_rounds: 0,
                failed_rounds: 0,
                average_completion_time: 0,
                total_penalties_collected: 0,
                total_contributions: 0,
                last_updated: get_block_timestamp(),
            };
            self.contribution_analytics.write(default_analytics);

            // Initialize system health metrics
            let default_health = SystemHealthMetrics {
                system_uptime_percentage: 100,
                active_rounds: 0,
                total_locked_value: 0,
                security_score: 100,
                member_satisfaction_score: 100,
                last_health_check: get_block_timestamp(),
            };
            self.system_metrics.write(default_health);

            // Initialize total system value
            self.total_system_value.write(0);
        }

        // Internal function to assert that the caller is the admin
        fn _assert_admin(self: @ComponentState<TContractState>) {
            let admin: ContractAddress = self.admin.read();
            let caller: ContractAddress = get_caller_address();
            assert(caller == admin, AnalyticsComponentErrors::NOT_ADMIN);
        }

        // Complex operations that will be called by the main contract
        fn _update_member_analytics(
            ref self: ComponentState<TContractState>,
            member: ContractAddress,
            payment_made: bool,
            amount: u256,
            round_id: u256,
        ) {
            let contract_state = self.get_contract();
            let mut analytics = self.member_analytics.read(member);

            // Update contribution statistics
            analytics.total_contributions += amount;
            analytics.total_rounds_participated += 1;

            if payment_made {
                analytics.on_time_payments += 1;
            } else {
                analytics.missed_payments += 1;
            }

            // Calculate average contribution amount
            if analytics.total_rounds_participated > 0 {
                analytics.average_contribution_amount = analytics.total_contributions
                    / analytics.total_rounds_participated;
            }

            // Update reliability score
            analytics
                .reliability_score = self
                ._calculate_reliability_score(
                    analytics.on_time_payments, analytics.total_rounds_participated,
                );
            analytics.last_updated = get_block_timestamp();

            self.member_analytics.write(member, analytics);

            self
                .emit(
                    Event::MemberAnalyticsUpdated(
                        MemberAnalyticsUpdated {
                            member,
                            reliability_score: analytics.reliability_score,
                            timestamp: get_block_timestamp(),
                        },
                    ),
                );
        }

        fn _update_round_metrics(
            ref self: ComponentState<TContractState>,
            round_id: u256,
            status: RoundStatus,
            total_contributions: u256,
            participant_count: u32,
        ) {
            let contract_state = self.get_contract();
            let round = contract_state.get_round_data(round_id);
            let current_time = get_block_timestamp();

            let mut metrics = self.round_metrics.read(round_id);
            metrics.round_id = round_id;
            metrics.total_contributions = total_contributions;
            metrics.participant_count = participant_count;

            // Calculate completion rate based on member count
            let member_count = contract_state.get_member_count();
            if member_count > 0 {
                metrics
                    .completion_rate = ((participant_count * 100) / member_count)
                    .try_into()
                    .unwrap();
            }

            // Calculate completion time if round is completed
            if status == RoundStatus::Completed {
                // Use the round's recorded completion timestamp, and compute delay vs deadline
                let completed_at = round.completed_at;
                metrics.completion_time = completed_at;
                if completed_at > 0 {
                    if completed_at > round.deadline {
                        metrics.average_delay = completed_at - round.deadline;
                    } else {
                        metrics.average_delay = 0;
                    }
                }
            }

            // Determine success status
            metrics.success_status = self._determine_success_status(metrics.completion_rate);

            self.round_metrics.write(round_id, metrics);

            self
                .emit(
                    Event::RoundMetricsUpdated(
                        RoundMetricsUpdated {
                            round_id,
                            completion_rate: metrics.completion_rate,
                            timestamp: get_block_timestamp(),
                        },
                    ),
                );
        }

        fn _update_contribution_analytics(ref self: ComponentState<TContractState>) {
            let contract_state = self.get_contract();
            let mut analytics = self.contribution_analytics.read();

            let total_rounds = contract_state.get_round_ids();
            let mut successful_rounds = 0;
            let mut failed_rounds = 0;
            let mut total_completion_time = 0;
            let mut completed_rounds_count = 0;

            // Calculate round statistics
            let mut round_id = 1;
            while round_id <= total_rounds {
                let round = contract_state.get_round_data(round_id);
                if round.status == RoundStatus::Completed {
                    successful_rounds += 1;
                    // Use recorded round metrics completion time if available
                    let metrics = self.round_metrics.read(round_id);
                    if metrics.completion_time > 0 {
                        total_completion_time += metrics.completion_time;
                        completed_rounds_count += 1;
                    }
                } else if round.status == RoundStatus::Cancelled {
                    failed_rounds += 1;
                }
                round_id += 1;
            }

            analytics.total_rounds = total_rounds;
            analytics.successful_rounds = successful_rounds;
            analytics.failed_rounds = failed_rounds;

            if completed_rounds_count > 0 {
                analytics.average_completion_time = total_completion_time / completed_rounds_count;
            }

            analytics.last_updated = get_block_timestamp();
            self.contribution_analytics.write(analytics);

            self
                .emit(
                    Event::AnalyticsUpdated(
                        AnalyticsUpdated {
                            admin: get_caller_address(), timestamp: get_block_timestamp(),
                        },
                    ),
                );
        }

        fn _update_system_health(ref self: ComponentState<TContractState>) {
            let contract_state = self.get_contract();
            let mut health = self.system_metrics.read();

            // Calculate active rounds
            let total_rounds = contract_state.get_round_ids();
            let mut active_rounds = 0;
            let mut round_id = 1;
            while round_id <= total_rounds {
                let round = contract_state.get_round_data(round_id);
                if round.status == RoundStatus::Active {
                    active_rounds += 1;
                }
                round_id += 1;
            }

            health.active_rounds = active_rounds.try_into().unwrap();
            health.total_locked_value = self.total_system_value.read();
            health.last_health_check = get_block_timestamp();

            // Calculate security score based on various factors
            health.security_score = self._calculate_security_score();

            self.system_metrics.write(health);

            self
                .emit(
                    Event::SystemHealthUpdated(
                        SystemHealthUpdated {
                            security_score: health.security_score,
                            uptime_percentage: health.system_uptime_percentage,
                            timestamp: get_block_timestamp(),
                        },
                    ),
                );
        }

        fn _generate_financial_report(
            self: @ComponentState<TContractState>, period_start: u64, period_end: u64,
        ) -> FinancialReport {
            let contract_state = self.get_contract();
            let analytics = self.contribution_analytics.read();

            let report = FinancialReport {
                period_start,
                period_end,
                total_contributions: analytics.total_contributions,
                total_fees_collected: analytics.total_penalties_collected, // Simplified
                total_penalties_collected: analytics.total_penalties_collected,
                active_members: contract_state.get_member_count(),
                rounds_completed: analytics.successful_rounds.try_into().unwrap(),
                average_round_completion_time: analytics.average_completion_time,
                system_uptime_percentage: 100 // Simplified
            };

            report
        }

        // Helper functions
        fn _calculate_reliability_score(
            self: @ComponentState<TContractState>, on_time_payments: u256, total_rounds: u256,
        ) -> u8 {
            if total_rounds == 0 {
                return 100;
            }

            let score = (on_time_payments * 100) / total_rounds;
            score.try_into().unwrap_or(100)
        }

        fn _determine_success_status(
            self: @ComponentState<TContractState>, completion_rate: u8,
        ) -> RoundSuccessStatus {
            if completion_rate >= 95 {
                RoundSuccessStatus::Outstanding
            } else if completion_rate >= 85 {
                RoundSuccessStatus::Good
            } else if completion_rate >= 70 {
                RoundSuccessStatus::Average
            } else if completion_rate >= 50 {
                RoundSuccessStatus::Poor
            } else {
                RoundSuccessStatus::Failed
            }
        }

        fn _calculate_security_score(self: @ComponentState<TContractState>) -> u8 {
            // Weighted security score based on available metrics
            // Metrics used:
            // - System uptime percentage (positive weight)
            // - Average round completion rate (positive weight)
            // - Verified/active members percentage via get_member_status (positive weight)
            // - Average member reliability score (positive weight)
            // Weights: uptime 30, completion 25, verified 25, reliability 20

            let contract_state = self.get_contract();

            // Uptime (0..100)
            let health = self.system_metrics.read();
            let uptime_score: u8 = health.system_uptime_percentage;

            // Average round completion rate (0..100)
            let total_rounds: u256 = contract_state.get_round_ids();
            let mut completion_sum: u256 = 0;
            let mut completion_count: u256 = 0;
            let mut r_id: u256 = 1;
            while r_id <= total_rounds {
                let rm = self.round_metrics.read(r_id);
                // Only count rounds that have a non-zero recorded completion rate
                if rm.completion_rate > 0_u8 {
                    completion_sum += (rm.completion_rate).into();
                    completion_count += 1;
                }
                r_id += 1;
            }
            let completion_avg_u8: u8 = if completion_count > 0 {
                let avg: u256 = completion_sum / completion_count;
                avg.try_into().unwrap_or(0_u8)
            } else {
                50_u8 // neutral default when there are no rounds
            };

            // Verified/active members percentage (0..100)
            let members_total: u32 = contract_state.get_member_count();
            let mut verified_count: u32 = 0;
            let mut idx: u32 = 0;
            while idx < members_total {
                let addr = contract_state.get_member_by_index(idx);
                if contract_state.get_member_status(addr) {
                    verified_count += 1;
                }
                idx += 1;
            }
            let verified_pct_u8: u8 = if members_total > 0 {
                let pct: u32 = (verified_count * 100_u32) / members_total;
                pct.try_into().unwrap_or(0_u8)
            } else {
                50_u8 // neutral default when there are no members
            };

            // Average member reliability (0..100)
            let mut reliability_sum: u256 = 0;
            let mut m_idx: u32 = 0;
            while m_idx < members_total {
                let m_addr = contract_state.get_member_by_index(m_idx);
                let ma = self.member_analytics.read(m_addr);
                reliability_sum += (ma.reliability_score).into();
                m_idx += 1;
            }
            let reliability_avg_u8: u8 = if members_total > 0 {
                let avg_rel: u256 = reliability_sum / (members_total.into());
                avg_rel.try_into().unwrap_or(0_u8)
            } else {
                50_u8
            };

            // Weighted combination; use u256 for intermediate math
            let w_uptime: u256 = (uptime_score).into() * 30_u256;
            let w_completion: u256 = (completion_avg_u8).into() * 25_u256;
            let w_verified: u256 = (verified_pct_u8).into() * 25_u256;
            let w_reliability: u256 = (reliability_avg_u8).into() * 20_u256;
            let total_weighted: u256 = w_uptime + w_completion + w_verified + w_reliability;
            let mut combined: u256 = total_weighted / 100_u256;

            // Clamp to 0..100
            if combined > 100_u256 {
                combined = 100_u256;
            }

            combined.try_into().unwrap_or(100_u8)
        }
    }
}
