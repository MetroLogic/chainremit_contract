use starknet::ContractAddress;

#[derive(PartialEq, Copy, Drop, Serde, starknet::Store)]
pub enum LoanStatus {
    #[default]
    Pending,
    Approved,
    Reject,
    Completed,
}

#[derive(Copy, Drop, Serde, starknet::Store)]
pub struct LoanRequest {
    pub id: u256,
    pub requester: ContractAddress,
    pub amount: u256,
    pub status: LoanStatus,
    pub created_at: u64,
}
