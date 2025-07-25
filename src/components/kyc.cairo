use starknet::ContractAddress;
use starknet::storage::{
    Map, StorageMapReadAccess, StorageMapWriteAccess, StoragePathEntry, StoragePointerReadAccess,
    StoragePointerWriteAccess,
};
use crate::base::events::kyc::*;
use crate::base::types::kyc::*;

#[starknet::interface]
pub trait IKyc<TContractState> {
    // KYC Management Functions
    fn update_kyc_status(
        ref self: TContractState,
        user: ContractAddress,
        status: KycStatus,
        level: KycLevel,
        verification_hash: felt252,
        expires_at: u64,
    ) -> bool;
    fn get_kyc_status(self: @TContractState, user: ContractAddress) -> (KycStatus, KycLevel);
    fn is_kyc_valid(self: @TContractState, user: ContractAddress) -> bool;
    fn is_kyc_enforcement_enabled(self: @TContractState) -> bool;
}

#[starknet::component]
pub mod kyc_component {
    use super::*;

    #[storage]
    struct Storage {
        // KYC storage
        kyc_enforcement_enabled: bool,
        user_kyc_data: Map<ContractAddress, UserKycData>,
        // Transaction limits stored per level (0=None, 1=Basic, 2=Enhanced, 3=Premium)
        daily_limits: Map<u8, u256>,
        single_limits: Map<u8, u256>,
        daily_usage: Map<ContractAddress, u256>,
        last_reset: Map<ContractAddress, u64>,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        KYCLevelUpdated: KYCLevelUpdated, // Event for KYC level updates
        KycStatusUpdated: KycStatusUpdated, // Event for KYC status updates
        KycEnforcementEnabled: KycEnforcementEnabled // Event for KYC enforcement
    }

    #[embeddable_as(Kyc)]
    impl KycImpl<
        TContractState, +HasComponent<TContractState>,
    > of IKyc<ComponentState<TContractState>> {}

    #[generate_trait]
    pub impl InternalImpl<
        TContractState, +HasComponent<TContractState>,
    > of InternalTrait<TContractState> {}
}
