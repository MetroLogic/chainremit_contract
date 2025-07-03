use starknet::ContractAddress;
/// @event LoanRequested
/// @notice Emitted when a loan is requested.
/// @param id The unique identifier of the loan.
/// @param requester The address of the requester.
/// @param amount The amount requested for the loan.
/// @param created_at The timestamp when the loan was requested.
#[derive(Copy, Drop, starknet::Event)]
pub struct LoanRequested {
    pub id: u256,
    pub requester: ContractAddress,
    pub amount: u256,
    pub created_at: u64,
}

/// @event LoanApproved
/// @notice Emitted when a loan is approved.
/// @param id The unique identifier of the loan.
/// @param auth The address of the approver (authority).
/// @param created_at The timestamp when the loan was approved.
#[derive(Copy, Drop, starknet::Event)]
pub struct LoanApproved {
    pub id: u256,
    pub auth: ContractAddress,
    pub created_at: u64,
}

/// @event LoanReject
/// @notice Emitted when a loan is rejected.
/// @param id The unique identifier of the loan.
/// @param auth The address of the rejector (authority).
/// @param created_at The timestamp when the loan was rejected.
#[derive(Copy, Drop, starknet::Event)]
pub struct LoanReject {
    pub id: u256,
    pub auth: ContractAddress,
    pub created_at: u64,
}

/// @event LoanRepaid
/// @notice Emitted when a loan repayment is made.
/// @param loan_id The unique identifier of the loan.
/// @param amount The amount repaid.
/// @param remaining_balance The remaining balance after repayment.
/// @param is_fully_repaid Indicates if the loan is fully repaid.
/// @param timestamp The timestamp of the repayment.
#[derive(Copy, Drop, starknet::Event)]
pub struct LoanRepaid {
    pub loan_id: u256,
    pub amount: u256,
    pub remaining_balance: u256,
    pub is_fully_repaid: bool,
    pub timestamp: u64,
}

/// @event LatePayment
/// @notice Emitted when a late payment occurs on a loan.
/// @param loan_id The unique identifier of the loan.
/// @param days_late The number of days the payment is late.
/// @param penalty_amount The penalty amount for the late payment.
/// @param timestamp The timestamp of the late payment event.
#[derive(Copy, Drop, starknet::Event)]
pub struct LatePayment {
    pub loan_id: u256,
    pub days_late: u256,
    pub penalty_amount: u256,
    pub timestamp: u64,
}
