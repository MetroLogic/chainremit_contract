use starknet::ContractAddress;
use starkremit_contract::base::types::{UserProfile, RegistrationRequest, RegistrationStatus};
#[starknet::interface]
    pub trait IUserManagement<TContractState> {
        fn register_user(ref self: TContractState, registration_data: RegistrationRequest) -> bool;
        fn get_user_profile(self: @TContractState, user_address: ContractAddress) -> UserProfile;
        fn update_user_profile(ref self: TContractState, updated_profile: UserProfile) -> bool;
        fn is_user_registered(self: @TContractState, user_address: ContractAddress) -> bool;
        fn get_registration_status(self: @TContractState, user_address: ContractAddress) -> RegistrationStatus;
        fn deactivate_user(ref self: TContractState, user_address: ContractAddress) -> bool;
        fn reactivate_user(ref self: TContractState, user_address: ContractAddress) -> bool;
        fn get_total_users(self: @TContractState) -> u256;
    }
#[starknet::component]
pub mod user_management_component {
    use super::*;
    use starknet::{get_caller_address, get_block_timestamp, ContractAddress};
    use starkremit_contract::base::errors::RegistrationErrors;
    use starkremit_contract::base::types::{UserProfile, RegistrationRequest, RegistrationStatus, KYCLevel};
    use core::num::traits::Zero;
    use starknet::storage::{StorageMapReadAccess, StorageMapWriteAccess, Map, StoragePointerReadAccess, StoragePointerWriteAccess};

    #[storage]
    pub struct Storage {
        user_profiles: Map<ContractAddress, UserProfile>,
        email_registry: Map<felt252, ContractAddress>,
        phone_registry: Map<felt252, ContractAddress>,
        registration_status: Map<ContractAddress, RegistrationStatus>,
        total_users: u256,
        registration_enabled: bool,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        UserRegistered: UserRegistered,
        UserProfileUpdated: UserProfileUpdated,
        UserDeactivated: UserDeactivated,
        UserReactivated: UserReactivated,
    }

    #[derive(Drop, starknet::Event)]
    pub struct UserRegistered {
        user_address: ContractAddress,
        email_hash: felt252,
        registration_timestamp: u64,
    }
    #[derive(Drop, starknet::Event)]
    pub struct UserProfileUpdated {
        user_address: ContractAddress,
        updated_fields: felt252,
    }
    #[derive(Drop, starknet::Event)]
    pub struct UserDeactivated {
        user_address: ContractAddress,
        admin: ContractAddress,
    }
    #[derive(Drop, starknet::Event)]
    pub struct UserReactivated {
        user_address: ContractAddress,
        admin: ContractAddress,
    }


    #[embeddable_as(UserManagement)]
    impl UserManagementImpl<
        TContractState, +HasComponent<TContractState>,
    > of IUserManagement<ComponentState<TContractState>> {
        fn register_user(ref self: ComponentState<TContractState>, registration_data: RegistrationRequest) -> bool {
            let caller = get_caller_address();
            assert(!caller.is_zero(), RegistrationErrors::ZERO_ADDRESS);
            // Check for duplicate email
            let existing_email_user = self.email_registry.read(registration_data.email_hash);
            assert(existing_email_user.is_zero(), RegistrationErrors::EMAIL_ALREADY_EXISTS);
            // Check for duplicate phone
            let existing_phone_user = self.phone_registry.read(registration_data.phone_hash);
            assert(existing_phone_user.is_zero(), RegistrationErrors::PHONE_ALREADY_EXISTS);
            // Set registration status to in progress
            self.registration_status.write(caller, RegistrationStatus::InProgress);
            // Create user profile
            let current_timestamp = get_block_timestamp();
            let user_profile = UserProfile {
                address: caller,
                user_address: caller,
                email_hash: registration_data.email_hash,
                phone_hash: registration_data.phone_hash,
                full_name: registration_data.full_name,
                kyc_level: KYCLevel::None,
                registration_timestamp: current_timestamp,
                is_active: true,
                country_code: registration_data.country_code,
            };
            self.user_profiles.write(caller, user_profile);
            self.email_registry.write(registration_data.email_hash, caller);
            self.phone_registry.write(registration_data.phone_hash, caller);
            self.registration_status.write(caller, RegistrationStatus::Completed);
            let current_total = self.total_users.read();
            self.total_users.write(current_total + 1);
            self.emit(Event::UserRegistered(UserRegistered {
                user_address: caller,
                email_hash: registration_data.email_hash,
                registration_timestamp: current_timestamp,
            }));
            true
        }
        fn get_user_profile(self: @ComponentState<TContractState>, user_address: ContractAddress) -> UserProfile {
            let status = self.registration_status.read(user_address);
            match status {
                RegistrationStatus::Completed => {},
                _ => { assert(false, RegistrationErrors::USER_NOT_FOUND); },
            }
            self.user_profiles.read(user_address)
        }
        fn update_user_profile(ref self: ComponentState<TContractState>, updated_profile: UserProfile) -> bool {
            let caller = get_caller_address();
            assert(updated_profile.user_address == caller, 'Cannot update other profile');
            let status = self.registration_status.read(caller);
            match status {
                RegistrationStatus::Completed => {},
                _ => { assert(false, RegistrationErrors::USER_NOT_FOUND); },
            }
            let current_profile = self.user_profiles.read(caller);
            assert(current_profile.is_active, RegistrationErrors::USER_INACTIVE);
            assert(updated_profile.address == current_profile.address, 'Cannot change address');
            assert(updated_profile.registration_timestamp == current_profile.registration_timestamp, 'Cannot change timestamp');
            if updated_profile.email_hash != current_profile.email_hash {
                let zero_address: ContractAddress = 0.try_into().unwrap();
                let existing_email_user = self.email_registry.read(updated_profile.email_hash);
                assert(existing_email_user.is_zero(), RegistrationErrors::EMAIL_ALREADY_EXISTS);
                self.email_registry.write(current_profile.email_hash, zero_address);
                self.email_registry.write(updated_profile.email_hash, caller);
            }
            if updated_profile.phone_hash != current_profile.phone_hash {
                let zero_address: ContractAddress = 0.try_into().unwrap();
                let existing_phone_user = self.phone_registry.read(updated_profile.phone_hash);
                assert(existing_phone_user.is_zero(), RegistrationErrors::PHONE_ALREADY_EXISTS);
                self.phone_registry.write(current_profile.phone_hash, zero_address);
                self.phone_registry.write(updated_profile.phone_hash, caller);
            }
            self.user_profiles.write(caller, updated_profile);
            self.emit(Event::UserProfileUpdated(UserProfileUpdated {
                user_address: caller,
                updated_fields: 'profile_updated',
            }));
            true
        }
        fn is_user_registered(self: @ComponentState<TContractState>, user_address: ContractAddress) -> bool {
            let status = self.registration_status.read(user_address);
            match status {
                RegistrationStatus::Completed => true,
                _ => false,
            }
        }
        fn get_registration_status(self: @ComponentState<TContractState>, user_address: ContractAddress) -> RegistrationStatus {
            self.registration_status.read(user_address)
        }
        fn deactivate_user(ref self: ComponentState<TContractState>, user_address: ContractAddress) -> bool {
            let caller = get_caller_address();
            let is_registered = match self.registration_status.read(user_address) {
                RegistrationStatus::Completed => true,
                _ => false,
            };
            assert(is_registered, RegistrationErrors::USER_NOT_FOUND);
            let mut user_profile = self.user_profiles.read(user_address);
            user_profile.is_active = false;
            self.user_profiles.write(user_address, user_profile);
            self.registration_status.write(user_address, RegistrationStatus::Suspended);
            self.emit(Event::UserDeactivated(UserDeactivated {
                user_address,
                admin: caller,
            }));
            true
        }
        fn reactivate_user(ref self: ComponentState<TContractState>, user_address: ContractAddress) -> bool {
            let caller = get_caller_address();
            let status = self.registration_status.read(user_address);
            match status {
                RegistrationStatus::Suspended => {},
                _ => { assert(false, 'User not suspended'); },
            }
            let mut user_profile = self.user_profiles.read(user_address);
            user_profile.is_active = true;
            self.user_profiles.write(user_address, user_profile);
            self.registration_status.write(user_address, RegistrationStatus::Completed);
            self.emit(Event::UserReactivated(UserReactivated {
                user_address,
                admin: caller,
            }));
            true
        }
        fn get_total_users(self: @ComponentState<TContractState>) -> u256 {
            self.total_users.read()
        }
    }

}
