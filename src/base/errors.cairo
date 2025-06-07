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
    pub const INSUFFICIENT_BUFFER: felt252 = 'ERC20: insufficient buffer size';
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

    /// Error triggered when user is not registered
    pub const USER_NOT_REGISTERED: felt252 = 'User not registered';

    pub const REGISTRATION_DISABLED: felt252 = 'Registration is disabled';
    pub const UNAUTHORIZED_PROFILE_UPDATE: felt252 = 'Unauthorized profile update';
    pub const IMMUTABLE_ADDRESS: felt252 = 'Address cannot be changed';
    // pub const IMMUTABLE_TIMESTAMP: felt252 = 'Registration timestamp cannot be changed';
    pub const USER_NOT_SUSPENDED: felt252 = 'User is not suspended';
    pub const RECIPIENT_NOT_FOUND: felt252 = 'Recipient not found';
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
    pub const INSUFFICIENT_RECIPIENT_KYC: felt252 = 'KYC: insufficient recipient KYC';
}

pub mod TransferErrors {
    /// Error triggered when transfer is not found
    pub const TRANSFER_NOT_FOUND: felt252 = 'Transfer not found';

    /// Error triggered when transfer has already expired
    pub const TRANSFER_EXPIRED: felt252 = 'Transfer has expired';

    /// Error triggered when transfer is already cancelled
    pub const TRANSFER_ALREADY_CANCELLED: felt252 = 'Transfer already cancelled';

    /// Error triggered when transfer is already completed
    pub const TRANSFER_ALREADY_COMPLETED: felt252 = 'Transfer already completed';

    /// Error triggered when transfer status is invalid for operation
    pub const INVALID_TRANSFER_STATUS: felt252 = 'Invalid transfer status';

    /// Error triggered when caller is not authorized for transfer operation
    pub const UNAUTHORIZED_TRANSFER_OP: felt252 = 'Unauthorized transfer op';

    /// Error triggered when transfer amount is invalid
    pub const INVALID_TRANSFER_AMOUNT: felt252 = 'Invalid transfer amount';

    /// Error triggered when transfer currency is not supported
    pub const UNSUPPORTED_CURRENCY: felt252 = 'Unsupported currency';

    /// Error triggered when partial amount exceeds total amount
    pub const PARTIAL_AMOUNT_EXCEEDS: felt252 = 'Partial exceeds total';

    /// Error triggered when agent is not found
    pub const AGENT_NOT_FOUND: felt252 = 'Agent not found';

    /// Error triggered when agent is not active
    pub const AGENT_NOT_ACTIVE: felt252 = 'Agent not active';

    /// Error triggered when agent is already registered
    pub const AGENT_ALREADY_EXISTS: felt252 = 'Agent already exists';

    /// Error triggered when agent is not authorized for operation
    pub const AGENT_NOT_AUTHORIZED: felt252 = 'Agent not authorized';

    /// Error triggered when transfer cannot be cancelled
    pub const CANNOT_CANCEL_TRANSFER: felt252 = 'Cannot cancel transfer';

    /// Error triggered when transfer expiry time is invalid
    pub const INVALID_EXPIRY_TIME: felt252 = 'Invalid expiry time';

    /// Error triggered when trying to assign invalid agent
    pub const INVALID_AGENT_ASSIGNMENT: felt252 = 'Invalid agent assignment';

    /// Error triggered when history entry is not found
    pub const HISTORY_NOT_FOUND: felt252 = 'History not found';

    /// Error triggered when search parameters are invalid
    pub const INVALID_SEARCH_PARAMS: felt252 = 'Invalid search parameters';

    /// Error triggered when agent is not assigned to transfer
    pub const AGENT_NOT_ASSIGNED: felt252 = 'Agent not assigned';
    pub const SELF_TRANSFER: felt252 = 'Self transfer not allowed';
    pub const INVALID_EXPIRY: felt252 = 'Invalid expiry';
    pub const ExchangeRateUpdated: felt252 = 'Exchange rate updated';
}

pub mod GroupErrors {
    /// Error triggered when the max members is less than two
    pub const INVALID_GROUP_SIZE: felt252 = 'GROUP: mini 2 members expected';

    /// Error triggered when trying to join an inactive group
    pub const GROUP_INACTIVE: felt252 = 'GROUP: group is inactive';

    /// Error triggered when trying to access an inactive group
    pub const GROUP_NOT_ACTIVE: felt252 = 'GROUP: group is not active';

    /// Error triggered when trying to join a group twice
    pub const ALREADY_MEMBER: felt252 = 'GROUP: caller already a member';

    /// Error triggered when the group is full
    pub const GROUP_FULL: felt252 = 'GROUP: group is full';
}

pub mod MintBurnErrors {
    /// Error triggered when the caller is not an authorized minter
    pub const NOT_MINTER: felt252 = 'Mint: caller is not a minter';
    /// Error triggered when trying to mint to the zero address
    pub const MINT_TO_ZERO: felt252 = 'Mint: mint to zero address';
    /// Error triggered when trying to mint zero tokens
    pub const MINT_ZERO_AMOUNT: felt252 = 'Mint: amount must be > 0';
    /// Error triggered when minting would exceed the maximum supply
    pub const MAX_SUPPLY_EXCEEDED: felt252 = 'Mint: exceeds max supply';
    /// Error triggered when trying to burn zero tokens
    pub const BURN_ZERO_AMOUNT: felt252 = 'Burn: amount must be > 0';
    /// Error triggered when trying to burn more tokens than available balance
    pub const INSUFFICIENT_BALANCE_BURN: felt252 = 'Burn: insufficient balance';
    /// Error triggered for invalid minter address management
    pub const INVALID_MINTER_ADDRESS: felt252 = 'MinterMgmt: invalid address';
    /// Error triggered if max supply is set too low
    pub const MAX_SUPPLY_TOO_LOW: felt252 = 'SetMaxSupply: too low';
}
