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

    /// Error triggered when the recipient has an insufficient kyc
    pub const INSUFFICIENT_RECIPIENT_KYC: felt252 = 'KYC: insufficient recipient KYC';
}
