use starknet::ContractAddress;
use starknet::storage::{
    Map, StorageMapReadAccess, StorageMapWriteAccess, StoragePathEntry, StoragePointerReadAccess,
    StoragePointerWriteAccess,
};
use crate::base::events::loans::*;
use crate::base::types::loans::*;
#[starknet::interface]
pub trait ILoans<TContractState> {
    // Loan Management Functions
    fn requestLoan(ref self: TContractState, requester: ContractAddress, amount: u256) -> u256;
    fn approveLoan(ref self: TContractState, loan_id: u256) -> u256;
    fn rejectLoan(ref self: TContractState, loan_id: u256) -> u256;
    fn getLoan(self: @TContractState, loan_id: u256) -> LoanRequest;
    fn get_loan_count(self: @TContractState) -> u256;
    fn get_user_active_Loan(self: @TContractState, user: ContractAddress) -> bool;
    fn has_active_loan_request(self: @TContractState, user: ContractAddress) -> bool;
    fn repay_loan(ref self: TContractState, loan_id: u256, amount: u256) -> (u256, u256);
}


#[starknet::component]
pub mod loan_component {
    use super::*;

    #[storage]
    struct Storage {
        loan_count: u256,
        loans: Map<u256, LoanRequest>,
        loan_request: Map<ContractAddress, bool>, // Track if a user has an active loan request
        active_loan: Map<ContractAddress, bool>, // Track active loan 
        // Loan repayment tracking
        loan_repayments: Map<u256, u256>, // loan_id -> amount_repaid
        loan_due_dates: Map<u256, u64>, // loan_id -> due_date_timestamp
        loan_interest_rates: Map<u256, u256>, // loan_id -> interest_rate_at_approval
        loan_penalties: Map<u256, u256>, // loan_id -> total_penalties_incurred
        loan_last_payment: Map<u256, u64>,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        LoanRequested: LoanRequested,
        LatePayment: LatePayment,
        LoanRepaid: LoanRepaid,
    }

    #[embeddable_as(Loan)]
    impl LoanImpl<
        TContractState, +HasComponent<TContractState>,
    > of ILoans<ComponentState<TContractState>> {}

    #[generate_trait]
    pub impl InternalImpl<
        TContractState, +HasComponent<TContractState>,
    > of InternalTrait<TContractState> {}
}
