pub mod ERC20Errors {
    /// Error triggered when transfer amount exceeds balance
    pub const INSUFFICIENT_BALANCE: felt252 = 'ERC20: insufficient balance';

    /// Error triggered when spender tries to transfer more than allowed
    pub const INSUFFICIENT_ALLOWANCE: felt252 = 'ERC20: insufficient allowance';

    /// Error triggered when transferring to the zero address
    pub const TRANSFER_TO_ZERO: felt252 = 'ERC20: transfer to 0 address';

    /// Error triggered when approving the zero address
    pub const APPROVE_TO_ZERO: felt252 = 'ERC20: approve to 0 address';

    /// Error triggered when minting to the zero address
    pub const MINT_TO_ZERO: felt252 = 'ERC20: mint to 0 address';

    /// Error triggered when burning from the zero address
    pub const BURN_FROM_ZERO: felt252 = 'ERC20: burn from 0 address';

    /// Error triggered when the caller is not the owner of the token
    pub const NotAdmin: felt252 = 'ERC20: not admin';
}

pub mod RegistrationErrors {
    /// Error triggered when user is already registered
    pub const USER_ALREADY_REGISTERED: felt252 = 'User already registered';

    /// Error triggered when email is already in use
    pub const EMAIL_ALREADY_EXISTS: felt252 = 'Email already exists';

    /// Error triggered when phone number is already in use
    pub const PHONE_ALREADY_EXISTS: felt252 = 'Phone already exists';

    /// Error triggered when full name is invalid
    pub const INVALID_FULL_NAME: felt252 = 'Invalid full name';

    /// Error triggered when email hash is invalid
    pub const INVALID_EMAIL_HASH: felt252 = 'Invalid email hash';

    /// Error triggered when phone hash is invalid
    pub const INVALID_PHONE_HASH: felt252 = 'Invalid phone hash';

    /// Error triggered when country code is invalid
    pub const INVALID_COUNTRY_CODE: felt252 = 'Invalid country code';

    /// Error triggered when preferred currency is not supported
    pub const UNSUPPORTED_CURRENCY: felt252 = 'Unsupported currency';

    /// Error triggered when user is not found
    pub const USER_NOT_FOUND: felt252 = 'User not found';

    /// Error triggered when user account is inactive
    pub const USER_INACTIVE: felt252 = 'User account inactive';

    /// Error triggered when zero address is provided
    pub const ZERO_ADDRESS: felt252 = 'Zero address not allowed';

    /// Error triggered when registration data is incomplete
    pub const INCOMPLETE_DATA: felt252 = 'Incomplete registration data';

    /// Error triggered when KYC level is insufficient
    pub const INSUFFICIENT_KYC: felt252 = 'Insufficient KYC level';

    /// Error triggered when registration has failed
    pub const REGISTRATION_FAILED: felt252 = 'Registration failed';

    /// Error triggered when user is suspended
    pub const USER_SUSPENDED: felt252 = 'User account suspended';
}
