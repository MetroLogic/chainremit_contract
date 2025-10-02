use starknet::ContractAddress;

#[starknet::interface]
pub trait IVerifier<TContractState> {
    /// Verifies a zero-knowledge proof for withdrawal
    ///
    /// # Arguments
    /// * `proof` - Array of field elements representing the ZK proof
    /// * `root` - Merkle root of the commitment tree
    /// * `nullifier_hash` - Hash of the nullifier to prevent double-spending
    /// * `recipient` - Address receiving the withdrawn funds
    /// * `relayer` - Address of the relayer (can be zero if no relayer)
    /// * `fee` - Fee paid to the relayer
    /// * `amount` - Amount being withdrawn
    ///
    /// # Returns
    /// * `bool` - True if the proof is valid, false otherwise
    fn verify_proof(
        ref self: TContractState,
        proof: Array<felt252>,
        root: felt252,
        nullifier_hash: felt252,
        recipient: ContractAddress,
        relayer: ContractAddress,
        fee: u256,
        amount: u256,
    ) -> bool;
}
