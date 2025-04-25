#[starknet::contract]
mod StarkRemit {
    use starknet::ContractAddress;

    #[storage]
    struct Storage {
        admin: ContractAddress,
    }
}
