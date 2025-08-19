use starknet::ContractAddress;
use starkremit_contract::base::types::LoanRequest;

#[starknet::interface]
pub trait ILoan<TContractState> {
    fn request_loan(ref self: TContractState, requester: ContractAddress, amount: u256) -> u256;
    fn approve_loan(
        ref self: TContractState, loan_id: u256, interest_rate: u256, duration_days: u64,
    ) -> u256;
    fn reject_loan(ref self: TContractState, loan_id: u256) -> u256;
    fn get_loan(self: @TContractState, loan_id: u256) -> LoanRequest;
    fn get_loan_count(self: @TContractState) -> u256;
    fn get_user_active_loan(self: @TContractState, user: ContractAddress) -> bool;
    fn has_active_loan_request(self: @TContractState, user: ContractAddress) -> bool;
    fn repay_loan(ref self: TContractState, loan_id: u256, amount: u256) -> (u256, u256);
}

#[starknet::component]
pub mod loan_component {
    use core::num::traits::Zero;
    use starknet::storage::{
        Map, StorageMapReadAccess, StorageMapWriteAccess, StoragePointerReadAccess,
        StoragePointerWriteAccess,
    };
    use starknet::{ContractAddress, get_block_timestamp, get_caller_address};
    use starkremit_contract::base::errors::RegistrationErrors;
    use starkremit_contract::base::types::{LoanRequest, LoanStatus};
    use super::*;

    #[storage]
    pub struct Storage {
        loan_count: u256,
        loans: Map<u256, LoanRequest>,
        loan_request: Map<ContractAddress, bool>,
        active_loan: Map<ContractAddress, bool>,
        loan_repayments: Map<u256, u256>,
        loan_due_dates: Map<u256, u64>,
        loan_interest_rates: Map<u256, u256>,
        loan_penalties: Map<u256, u256>,
        loan_last_payment: Map<u256, u64>,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        LoanRequested: LoanRequested,
        LoanApproved: LoanApproved,
        LoanRejected: LoanRejected,
        LatePayment: LatePayment,
        LoanRepaid: LoanRepaid,
    }
    #[derive(Drop, starknet::Event)]
    pub struct LoanRequested {
        id: u256,
        requester: ContractAddress,
        amount: u256,
        created_at: u64,
    }
    #[derive(Drop, starknet::Event)]
    pub struct LoanApproved {
        id: u256,
        requester: ContractAddress,
        amount: u256,
        approved_at: u64,
    }
    #[derive(Drop, starknet::Event)]
    pub struct LoanRejected {
        id: u256,
        requester: ContractAddress,
        amount: u256,
        rejected_at: u64,
    }
    #[derive(Drop, starknet::Event)]
    pub struct LatePayment {
        loan_id: u256,
        days_late: u64,
        penalty_amount: u256,
        timestamp: u64,
    }
    #[derive(Drop, starknet::Event)]
    pub struct LoanRepaid {
        loan_id: u256,
        amount: u256,
        remaining_balance: u256,
        is_fully_repaid: bool,
        timestamp: u64,
    }

    #[embeddable_as(Loan)]
    impl LoanImpl<
        TContractState, +HasComponent<TContractState>,
    > of ILoan<ComponentState<TContractState>> {
        fn request_loan(
            ref self: ComponentState<TContractState>, requester: ContractAddress, amount: u256,
        ) -> u256 {
            let caller = get_caller_address();
            assert(!caller.is_zero(), RegistrationErrors::ZERO_ADDRESS);
            assert(amount > 0, 'loan amount is zero');
            assert(!self.active_loan.read(requester), 'User already has an active loan');
            assert(!self.loan_request.read(requester), 'has pending loan request');
            let created_at = get_block_timestamp();
            let loan_id: u256 = self.loan_count.read();
            let loan = LoanRequest {
                id: loan_id,
                requester: requester,
                amount: amount,
                status: LoanStatus::Pending,
                created_at: created_at,
            };
            self.loan_count.write(loan_id + 1);
            self.loans.write(loan_id, loan);
            self.loan_request.write(requester, true);
            self
                .emit(
                    Event::LoanRequested(
                        LoanRequested {
                            id: loan_id,
                            requester: requester,
                            amount: amount,
                            created_at: created_at,
                        },
                    ),
                );
            loan_id
        }
        fn approve_loan(
            ref self: ComponentState<TContractState>,
            loan_id: u256,
            interest_rate: u256,
            duration_days: u64,
        ) -> u256 {
            let mut loan = self.loans.read(loan_id);
            assert(self.loan_request.read(loan.requester), 'no loan request');
            assert(loan.status == LoanStatus::Pending, 'loan request is not pending');
            assert(loan.amount > 0, 'loan amount is zero');

            self.loan_interest_rates.write(loan_id, interest_rate);
            self.loan_due_dates.write(loan_id, get_block_timestamp() + duration_days);
            self.loan_last_payment.write(loan_id, 0);
            self.active_loan.write(loan.requester, true);
            self.loan_request.write(loan.requester, false);

            loan.status == LoanStatus::Approved;
            self.loans.write(loan_id, loan);
            self
                .emit(
                    Event::LoanApproved(
                        LoanApproved {
                            id: loan.id,
                            requester: loan.requester,
                            amount: loan.amount,
                            approved_at: get_block_timestamp(),
                        },
                    ),
                );
            loan_id
        }
        fn reject_loan(ref self: ComponentState<TContractState>, loan_id: u256) -> u256 {
            let mut loan = self.loans.read(loan_id);
            loan.status == LoanStatus::Reject;

            self.loan_request.write(loan.requester, false);
            self.loans.write(loan_id, loan);
            self
                .emit(
                    Event::LoanRejected(
                        LoanRejected {
                            id: loan.id,
                            requester: loan.requester,
                            amount: loan.amount,
                            rejected_at: get_block_timestamp(),
                        },
                    ),
                );
            loan_id
        }
        fn get_loan(self: @ComponentState<TContractState>, loan_id: u256) -> LoanRequest {
            let loan = self.loans.read(loan_id);
            assert(loan.id == loan_id, 'Loan request not found');
            loan
        }
        fn get_loan_count(self: @ComponentState<TContractState>) -> u256 {
            self.loan_count.read()
        }
        fn get_user_active_loan(
            self: @ComponentState<TContractState>, user: ContractAddress,
        ) -> bool {
            self.active_loan.read(user)
        }
        fn has_active_loan_request(
            self: @ComponentState<TContractState>, user: ContractAddress,
        ) -> bool {
            self.loan_request.read(user)
        }
        fn repay_loan(
            ref self: ComponentState<TContractState>, loan_id: u256, amount: u256,
        ) -> (u256, u256) {
            let caller = get_caller_address();
            let current_time = get_block_timestamp();
            let mut loan = self.get_loan(loan_id);
            assert(loan.status == LoanStatus::Approved, 'Loan is not approved');
            assert(loan.requester == caller, 'Not the loan owner');
            assert(amount > 0, 'Amount must be positive');
            let amount_repaid = self.loan_repayments.read(loan_id);
            let due_date = self.loan_due_dates.read(loan_id);
            let interest_rate = self.loan_interest_rates.read(loan_id);
            let last_payment = self.loan_last_payment.read(loan_id);
            let days_elapsed = (current_time - last_payment).into() / 86400;
            let interest = (loan.amount * interest_rate * days_elapsed) / (100 * 365 * 100);
            let mut penalty = 0;
            if current_time > due_date {
                let days_late_u256 = ((current_time - due_date).into() / 86400) + 1;
                let days_late: u64 = days_late_u256.try_into().unwrap_or(0);
                penalty = (loan.amount * 100 * days_late_u256)
                    / (100 * 100 * 100); // LATE_PENALTY_RATE = 100
                self.loan_penalties.write(loan_id, self.loan_penalties.read(loan_id) + penalty);
                self
                    .emit(
                        Event::LatePayment(
                            LatePayment {
                                loan_id,
                                days_late,
                                penalty_amount: penalty,
                                timestamp: current_time,
                            },
                        ),
                    );
            }
            let total_balance = loan.amount + interest + penalty - amount_repaid;
            let actual_payment = if amount > total_balance {
                total_balance
            } else {
                amount
            };
            let new_amount_repaid = amount_repaid + actual_payment;
            let remaining_balance = total_balance - actual_payment;
            self.loan_repayments.write(loan_id, new_amount_repaid);
            self.loan_last_payment.write(loan_id, current_time);
            let is_fully_repaid = remaining_balance == 0;
            if is_fully_repaid {
                loan.status = LoanStatus::Completed;
                self.loans.write(loan_id, loan);
                self.active_loan.write(caller, false);
            }
            self
                .emit(
                    Event::LoanRepaid(
                        LoanRepaid {
                            loan_id,
                            amount: actual_payment,
                            remaining_balance,
                            is_fully_repaid,
                            timestamp: current_time,
                        },
                    ),
                );
            (actual_payment, remaining_balance)
        }
    }
}
