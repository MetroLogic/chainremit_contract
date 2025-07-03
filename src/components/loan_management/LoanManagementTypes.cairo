use starknet::ContractAddress;

/// @title LoanStatus Enum
/// @notice Represents the various statuses a loan request can have.
/// @dev Used to track the state of a loan request throughout its lifecycle.
/// @variant Pending The loan request is awaiting approval.
/// @variant Approved The loan request has been approved.
/// @variant Reject The loan request has been rejected.
/// @variant Completed The loan request has been completed.
#[derive(PartialEq, Copy, Drop, Serde, starknet::Store)]
pub enum LoanStatus {
    #[default]
    Pending,
    Approved,
    Reject,
    Completed,
}

/// @title LoanRequest Struct
/// @notice Contains all relevant information about a loan request.
/// @dev Used to store and manage loan request data within the contract.
/// @field id Unique identifier for the loan request.
/// @field requester Address of the user who requested the loan.
/// @field amount The amount requested for the loan.
/// @field status The current status of the loan request.
/// @field created_at Timestamp indicating when the loan request was created.
#[derive(Copy, Drop, Serde, starknet::Store)]
pub struct LoanRequest {
    pub id: u256,
    pub requester: ContractAddress,
    pub amount: u256,
    pub status: LoanStatus,
    pub created_at: u64,
}
