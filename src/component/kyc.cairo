use starknet::ContractAddress;
 use starkremit_contract::base::types::{KycStatus, KycLevel, KYCLevel};
#[starknet::interface]
pub trait IKYC<TContractState> {
    fn update_kyc_status(ref self: TContractState, user: ContractAddress, status: KycStatus, level: KycLevel, verification_hash: felt252, expires_at: u64) -> bool;
    fn get_kyc_status(self: @TContractState, user: ContractAddress) -> (KycStatus, KycLevel);
    fn is_kyc_valid(self: @TContractState, user: ContractAddress) -> bool;
    fn set_kyc_enforcement(ref self: TContractState, enabled: bool) -> bool;
    fn suspend_user_kyc(ref self: TContractState, user: ContractAddress) -> bool;
    fn reinstate_user_kyc(ref self: TContractState, user: ContractAddress) -> bool;
    fn update_kyc_level(ref self: TContractState, user_address: ContractAddress, kyc_level: KycLevel) -> bool;
}

#[starknet::component]
pub mod kyc_component {
    use super::*;
    use starknet::{get_caller_address, get_block_timestamp, ContractAddress};
    use starkremit_contract::base::errors::{KYCErrors, RegistrationErrors};
    use starkremit_contract::base::types::{KycStatus, KycLevel, UserKycData, KYCLevel, RegistrationStatus};
    use starknet::storage::{StorageMapReadAccess, StorageMapWriteAccess, Map, StoragePointerWriteAccess};

    #[storage]
    pub struct Storage {
        kyc_enforcement_enabled: bool,
        user_kyc_data: Map<ContractAddress, UserKycData>,
        daily_limits: Map<u8, u256>,
        single_limits: Map<u8, u256>,
        daily_usage: Map<ContractAddress, u256>,
        last_reset: Map<ContractAddress, u64>,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        KYCLevelUpdated: KYCLevelUpdated,
        KycStatusUpdated: KycStatusUpdated,
        KycEnforcementEnabled: KycEnforcementEnabled,
    }

    #[derive(Drop, starknet::Event)]
    pub struct KYCLevelUpdated {
        user_address: ContractAddress,
        old_level: KycLevel,
        new_level: KycLevel,
        admin: ContractAddress,
    }
    #[derive(Drop, starknet::Event)]
    pub struct KycStatusUpdated {
        user: ContractAddress,
        old_status: KycStatus,
        new_status: KycStatus,
        old_level: KycLevel,
        new_level: KycLevel,
    }
    #[derive(Drop, starknet::Event)]
    pub struct KycEnforcementEnabled {
        enabled: bool,
        updated_by: ContractAddress,
    }

    #[embeddable_as(KYC)]
    impl KYCImpl<
        TContractState, +HasComponent<TContractState>,
    > of IKYC<ComponentState<TContractState>> {
        fn update_kyc_status(ref self: ComponentState<TContractState>, user: ContractAddress, status: KycStatus, level: KycLevel, verification_hash: felt252, expires_at: u64) -> bool {
            let _caller = get_caller_address();
            // Only admin should be able to call this in a real contract
            let current_data = self.user_kyc_data.read(user);
            let old_status = current_data.status;
            let old_level = current_data.level;
            let updated_data = UserKycData {
                user,
                level,
                status,
                verification_hash,
                verified_at: get_block_timestamp(),
                expires_at,
            };
            self.user_kyc_data.write(user, updated_data);
            self.emit(Event::KycStatusUpdated(KycStatusUpdated {
                user,
                old_status,
                new_status: status,
                old_level,
                new_level: level,
            }));
            true
        }
        fn get_kyc_status(self: @ComponentState<TContractState>, user: ContractAddress) -> (KycStatus, KycLevel) {
            let kyc_data = self.user_kyc_data.read(user);
            let current_time = get_block_timestamp();
            if kyc_data.expires_at > 0 && current_time > kyc_data.expires_at {
                return (KycStatus::Expired, kyc_data.level);
            }
            (kyc_data.status, kyc_data.level)
        }
        fn is_kyc_valid(self: @ComponentState<TContractState>, user: ContractAddress) -> bool {
            let kyc_data = self.user_kyc_data.read(user);
            let current_time = get_block_timestamp();
            match kyc_data.status {
                KycStatus::Approved => {
                    if kyc_data.expires_at > current_time {
                        true
                    } else {
                        false
                    }
                },
                _ => false,
            }
        }
        fn set_kyc_enforcement(ref self: ComponentState<TContractState>, enabled: bool) -> bool {
            let caller = get_caller_address();
            self.kyc_enforcement_enabled.write(enabled);
            self.emit(Event::KycEnforcementEnabled(KycEnforcementEnabled {
                enabled,
                updated_by: caller,
            }));
            true
        }
        fn suspend_user_kyc(ref self: ComponentState<TContractState>, user: ContractAddress) -> bool {
            let _caller = get_caller_address();
            let mut kyc_data = self.user_kyc_data.read(user);
            let old_status = kyc_data.status;
            kyc_data.status = KycStatus::Suspended;
            self.user_kyc_data.write(user, kyc_data);
            self.emit(Event::KycStatusUpdated(KycStatusUpdated {
                user,
                old_status,
                new_status: KycStatus::Suspended,
                old_level: kyc_data.level,
                new_level: kyc_data.level,
            }));
            true
        }
        fn reinstate_user_kyc(ref self: ComponentState<TContractState>, user: ContractAddress) -> bool {
            let _caller = get_caller_address();
            let mut kyc_data = self.user_kyc_data.read(user);
            let old_status = kyc_data.status;
            assert(old_status == KycStatus::Suspended, KYCErrors::INVALID_KYC_STATUS);
            kyc_data.status = KycStatus::Approved;
            self.user_kyc_data.write(user, kyc_data);
            self.emit(Event::KycStatusUpdated(KycStatusUpdated {
                user,
                old_status,
                new_status: KycStatus::Approved,
                old_level: kyc_data.level,
                new_level: kyc_data.level,
            }));
            true
        }
        fn update_kyc_level(ref self: ComponentState<TContractState>, user_address: ContractAddress, kyc_level: KycLevel) -> bool {
            let caller = get_caller_address();
            let mut kyc_data = self.user_kyc_data.read(user_address);
            let old_level = kyc_data.level;
            kyc_data.level = kyc_level;
            self.user_kyc_data.write(user_address, kyc_data);
            self.emit(Event::KYCLevelUpdated(KYCLevelUpdated {
                user_address,
                old_level,
                new_level: kyc_level,
                admin: caller,
            }));
            true
        }
    }

}

