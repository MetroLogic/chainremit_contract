use starknet::ContractAddress;
use super::LoanManagementTypes::LoanRequest;
#[starknet::interface]
pub trait ILoanManagement<TContractState> {
    /// @notice Requests a new loan for the specified requester and amount.
    /// @param self The contract state reference.
    /// @param requester The address of the user requesting the loan.
    /// @param amount The amount of the loan requested.
    /// @return The unique identifier of the created loan request.
    fn requestLoan(ref self: TContractState, requester: ContractAddress, amount: u256) -> u256;

    /// @notice Approves a pending loan request.
    /// @param self The contract state reference.
    /// @param loan_id The unique identifier of the loan to approve.
    /// @return The status code or updated loan state.
    fn approveLoan(ref self: TContractState, loan_id: u256) -> u256;


    /// @notice Rejects a pending loan request.
    /// @param self The contract state reference.
    /// @param loan_id The unique identifier of the loan to reject.
    /// @return The status code or updated loan state.
    fn rejectLoan(ref self: TContractState, loan_id: u256) -> u256;


    /// @notice Retrieves the details of a specific loan request.
    /// @param self The contract state reference.
    /// @param loan_id The unique identifier of the loan.
    /// @return The LoanRequest struct containing loan details.
    fn getLoan(self: @TContractState, loan_id: u256) -> LoanRequest;


    /// @notice Gets the total number of loan requests.
    /// @param self The contract state reference.
    /// @return The count of all loan requests.
    fn get_loan_count(self: @TContractState) -> u256;


    /// @notice Checks if a user currently has an active loan.
    /// @param self The contract state reference.
    /// @param user The address of the user to check.
    /// @return True if the user has an active loan, false otherwise.
    fn get_user_active_Loan(self: @TContractState, user: ContractAddress) -> bool;

    /// @notice Checks if a user has an active loan request.
    /// @param self The contract state reference.
    /// @param user The address of the user to check.
    /// @return True if the user has an active loan request, false otherwise.
    fn has_active_loan_request(self: @TContractState, user: ContractAddress) -> bool;

    /// @notice Repays a specified amount towards a loan.
    /// @param self The contract state reference.
    /// @param loan_id The unique identifier of the loan to repay.
    /// @param amount The amount to repay.
    /// @return A tuple containing the updated loan balance and the amount repaid.
    fn repay_loan(ref self: TContractState, loan_id: u256, amount: u256) -> (u256, u256);
}
