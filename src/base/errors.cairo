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

pub mod KYCErrors {
    /// Error triggered when user has insufficient KYC level
    pub const INSUFFICIENT_KYC_LEVEL: felt252 = 'KYC: insufficient level';

    /// Error triggered when KYC verification has expired
    pub const KYC_EXPIRED: felt252 = 'KYC: verification expired';

    /// Error triggered when KYC status is invalid for operation
    pub const INVALID_KYC_STATUS: felt252 = 'KYC: invalid status';

    /// Error triggered when KYC provider is not found
    pub const PROVIDER_NOT_FOUND: felt252 = 'KYC: provider not found';

    /// Error triggered when KYC provider is inactive
    pub const PROVIDER_INACTIVE: felt252 = 'KYC: provider inactive';

    /// Error triggered when trying to register existing provider
    pub const PROVIDER_ALREADY_EXISTS: felt252 = 'KYC: provider exists';

    /// Error triggered when caller is not authorized for KYC operations
    pub const UNAUTHORIZED_KYC_OPERATION: felt252 = 'KYC: unauthorized operation';

    /// Error triggered when transaction exceeds limits
    pub const TRANSACTION_LIMIT_EXCEEDED: felt252 = 'KYC: limit exceeded';

    /// Error triggered when daily limit is exceeded
    pub const DAILY_LIMIT_EXCEEDED: felt252 = 'KYC: daily limit exceeded';

    /// Error triggered when monthly limit is exceeded
    pub const MONTHLY_LIMIT_EXCEEDED: felt252 = 'KYC: monthly limit exceeded';

    /// Error triggered when annual limit is exceeded
    pub const ANNUAL_LIMIT_EXCEEDED: felt252 = 'KYC: annual limit exceeded';

    /// Error triggered when single transaction limit is exceeded
    pub const SINGLE_TX_LIMIT_EXCEEDED: felt252 = 'KYC: single tx limit exceeded';

    /// Error triggered when verification hash is invalid
    pub const INVALID_VERIFICATION_HASH: felt252 = 'KYC: invalid hash';

    /// Error triggered when KYC verification is suspended
    pub const KYC_SUSPENDED: felt252 = 'KYC: verification suspended';

    /// Error triggered when KYC verification is rejected
    pub const KYC_REJECTED: felt252 = 'KYC: verification rejected';

    /// Error triggered when KYC verification is pending
    pub const KYC_PENDING: felt252 = 'KYC: verification pending';

    /// Error triggered when arrays have mismatched lengths
    pub const ARRAY_LENGTH_MISMATCH: felt252 = 'KYC: array length mismatch';

    /// Error triggered when document hash already exists
    pub const DOCUMENT_HASH_EXISTS: felt252 = 'KYC: document hash exists';

    /// Error triggered when KYC data not found for user
    pub const KYC_DATA_NOT_FOUND: felt252 = 'KYC: data not found';
}
