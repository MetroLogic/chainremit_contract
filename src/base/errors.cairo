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
    // pub const UNSUPPORTED_CURRENCY: felt252 = 'Unsupported currency';

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

    pub const NOT_USER_ADMIN: felt252 = 'Not user admin';
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
    // pub const UNSUPPORTED_CURRENCY: felt252 = 'Unsupported currency';

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

    /// Error triggered when trying to join a group that has not been created
    pub const GROUP_NOT_CREATED: felt252 = 'GROUP: group is nonexistent';

    /// Error triggered when an invalid group id is provided
    pub const INVALID_GROUP_ID: felt252 = 'GROUP: invalid group id';
}

pub mod MintBurnErrors {
    /// Error triggered when the caller is not an authorized minter
    pub const NOT_MINTER: felt252 = 'Mint: caller is not a minter';
    /// Error triggered when the caller is not the owner
    pub const NOT_OWNER: felt252 = 'Token: caller is not owner';
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
    /// Error triggered when spender tries to transfer more than allowed
    pub const INSUFFICIENT_ALLOWANCE: felt252 = 'ERC20: insufficient allowance';
    /// Error triggered for invalid minter address management
    pub const INVALID_MINTER_ADDRESS: felt252 = 'MinterMgmt: invalid address';
    /// Error triggered if max supply is set too low
    pub const MAX_SUPPLY_TOO_LOW: felt252 = 'SetMaxSupply: too low';
    /// Error triggered when contract is paused
    pub const CONTRACT_PAUSED: felt252 = 'Token: contract is paused';
    /// Error triggered when trying to transfer to zero address
    pub const TRANSFER_TO_ZERO: felt252 = 'Token: transfer to zero';
    /// Error triggered when trying to transfer zero amount
    pub const TRANSFER_ZERO_AMOUNT: felt252 = 'Token: zero amount';
    /// Error triggered when trying to approve zero address
    pub const APPROVE_TO_ZERO: felt252 = 'Token: approve to zero';
    /// Error triggered when trying to set invalid max supply
    pub const INVALID_MAX_SUPPLY: felt252 = 'Token: invalid max supply';
    /// Error triggered when trying to transfer ownership to zero address
    pub const OWNERSHIP_TO_ZERO: felt252 = 'Token: ownership to zero';
    /// Error triggered when trying to transfer ownership to self
    pub const OWNERSHIP_TO_SELF: felt252 = 'Token: ownership to self';
}

pub mod GovernanceErrors {
    /// Error triggered when caller lacks required admin role
    pub const INSUFFICIENT_ROLE: felt252 = 'GOV: insufficient role';

    /// Error triggered when trying to assign invalid role
    pub const INVALID_ROLE: felt252 = 'GOV: invalid role';

    /// Error triggered when parameter value is out of bounds
    pub const PARAM_OUT_OF_BOUNDS: felt252 = 'GOV: param out of bounds';

    /// Error triggered when parameter key doesn't exist
    pub const PARAM_NOT_FOUND: felt252 = 'GOV: param not found';

    /// Error triggered when contract address is invalid
    pub const INVALID_CONTRACT: felt252 = 'GOV: invalid contract';

    /// Error triggered when timelock period hasn't passed
    pub const TIMELOCK_NOT_READY: felt252 = 'GOV: timelock not ready';

    /// Error triggered when trying to execute non-existent timelock
    pub const TIMELOCK_NOT_FOUND: felt252 = 'GOV: timelock not found';

    /// Error triggered when timelock has expired
    pub const TIMELOCK_EXPIRED: felt252 = 'GOV: timelock expired';

    /// Error triggered when trying to cancel unauthorized timelock
    pub const UNAUTHORIZED_CANCEL: felt252 = 'GOV: unauthorized cancel';

    /// Error triggered when trying to set invalid bounds
    pub const INVALID_BOUNDS: felt252 = 'GOV: invalid bounds';

    /// Error triggered when contract registry key exists
    pub const REGISTRY_KEY_EXISTS: felt252 = 'GOV: registry key exists';

    /// Error triggered when parameter update requires timelock
    pub const REQUIRES_TIMELOCK: felt252 = 'GOV: requires timelock';

    /// Error triggered when caller is not a SuperAdmin
    pub const NOT_SUPERADMIN: felt252 = 'GOV: insufficient role';

    /// Error triggered when caller is not an Admin or higher
    pub const NOT_ADMIN: felt252 = 'GOV: insufficient role';

    /// Error triggered when parameter is out of bounds
    pub const OUT_OF_BOUNDS: felt252 = 'GOV: param out of bounds';

    /// Error triggered when timelock conditions are not met
    pub const TIMELOCK: felt252 = 'GOV: timelock not ready';

    /// Error triggered when operation is not allowed
    pub const NOT_ALLOWED: felt252 = 'GOV: unauthorized cancel';

    /// Error triggered when zero address is provided
    pub const ZERO_ADDRESS: felt252 = 'GOV: invalid contract';
}

pub mod EmergencyComponentErrors {
    /// Error triggered when caller is not an Admin or higher
    pub const NOT_ADMIN: felt252 = 'Emergency: not admin';
    /// Error triggered when contract is paused
    pub const CONTRACT_PAUSED: felt252 = 'Emergency: contract is paused';
    /// Error triggered when contract is not paused
    pub const CONTRACT_NOT_PAUSED: felt252 = 'Emergency: contract not paused';
    /// Error triggered when member is already banned
    pub const MEMBER_ALREADY_BANNED: felt252 = 'Emergency: member is banned';
    /// Error triggered when member is not banned
    pub const MEMBER_NOT_BANNED: felt252 = 'Emergency: member is not banned';
    /// Error triggered when contract is already paused
    pub const ALREADY_PAUSED: felt252 = 'Emergency: contract is paused';
}

pub mod EmergencyErrors {
    /// Error triggered when no funds available for withdrawal
    pub const NO_FUNDS_TO_WITHDRAW: felt252 = 'Emergency: no funds';
    /// Error triggered when member does not exist
    pub const MEMBER_NOT_EXISTS: felt252 = 'Emergency: member not found';
    /// Error triggered when member has no contributions
    pub const MEMBER_NO_CONTRIBUTIONS: felt252 = 'Emergency: no contributions';
    /// Error triggered when round is not active
    pub const ROUND_NOT_ACTIVE: felt252 = 'Emergency: round inactive';
    /// Error triggered when recipient address is invalid
    pub const INVALID_RECIPIENT: felt252 = 'Emergency: invalid recipient';
    /// Error triggered when new recipient is not a member
    pub const RECIPIENT_NOT_MEMBER: felt252 = 'Emergency: not member';
    /// Error triggered when recipient is already set
    pub const RECIPIENT_ALREADY_SET: felt252 = 'Emergency: recipient set';
    /// Error triggered when token address is invalid
    pub const INVALID_TOKEN_ADDRESS: felt252 = 'Emergency: invalid token';
    /// Error triggered when amount is invalid
    pub const INVALID_AMOUNT: felt252 = 'Emergency: invalid amount';
    /// Error triggered when balance is insufficient
    pub const INSUFFICIENT_BALANCE: felt252 = 'Emergency: insufficient';
    /// Error triggered when contract address is invalid
    pub const INVALID_CONTRACT_ADDRESS: felt252 = 'Emergency: invalid contract';
    /// Error triggered when trying to migrate to self
    pub const CANNOT_MIGRATE_TO_SELF: felt252 = 'Emergency: migrate to self';
    /// Error triggered when migration target is invalid
    pub const INVALID_MIGRATION_TARGET: felt252 = 'Emergency: invalid target';
    /// Error triggered when no funds to migrate
    pub const NO_FUNDS_TO_MIGRATE: felt252 = 'Emergency: no funds';
}

pub mod PenaltyComponentErrors {
    /// Error triggered when caller is not an Admin or higher
    pub const NOT_ADMIN: felt252 = 'Penalty: not admin';
    /// Error triggered when contract is paused
    pub const CONTRACT_PAUSED: felt252 = 'Penalty: contract is paused';
    /// Error triggered when contract is not paused
    pub const CONTRACT_NOT_PAUSED: felt252 = 'Penalty: contract not paused';
    /// Error triggered when penalty pool is disabled
    pub const PENALTY_POOL_DISABLED: felt252 = 'Penalty: penalty pool disabled';
    /// Error triggered when no contribution for round
    pub const NO_CONTRIBUTION_FOR_ROUND: felt252 = 'Penalty: no contribution';
    /// Error triggered when not late
    pub const NOT_LATE: felt252 = 'Penalty: not late';
}

pub mod AutoScheduleErrors {
    /// Error triggered when caller is not an Admin or higher
    pub const NOT_ADMIN: felt252 = 'AutoSchedule: not admin';
    /// Error triggered when contract is paused
    pub const CONTRACT_PAUSED: felt252 = 'AutoSchedule: paused';
    /// Error triggered when contract is not paused
    pub const CONTRACT_NOT_PAUSED: felt252 = 'AutoSchedule: not paused';
    /// Error triggered when new deadline is not in the future
    pub const NEW_DEADLINE_NOT_IN_FUTURE: felt252 = 'AutoSchedule: not future';
    /// Error triggered when new deadline is not after start
    pub const NEW_DEADLINE_NOT_AFTER_START: felt252 = 'AutoSchedule: not after start';
}

pub mod ContributionErrors {
    /// Error triggered when caller is not a member
    pub const NOT_MEMBER: felt252 = 'Contribution: not member';
    /// Error triggered when member already contributed
    pub const ALREADY_CONTRIBUTED: felt252 = 'Contribution: contributed';
    /// Error triggered when round is not active
    pub const ROUND_NOT_ACTIVE: felt252 = 'Contribution: not active';
    /// Error triggered when contribution deadline passed
    pub const CONTRIBUTION_DEADLINE_PASSED: felt252 = 'Contribution: deadline passed';
    /// Error triggered when contribution amount is insufficient
    pub const INSUFFICIENT_AMOUNT: felt252 = 'Contribution: insufficient';
    /// Error triggered when contribution limit exceeded
    pub const CONTRIBUTION_LIMIT_EXCEEDED: felt252 = 'Contribution: limit exceeded';
    /// Error triggered when recipient is not a member
    pub const RECIPIENT_NOT_MEMBER: felt252 = 'Contribution: not member';
    /// Error triggered when deadline is not in future
    pub const DEADLINE_NOT_IN_FUTURE: felt252 = 'Contribution: not future';
    /// Error triggered when round deadline not passed
    pub const ROUND_DEADLINE_NOT_PASSED: felt252 = 'Contribution: not deadline ';
    /// Error triggered when round not completed
    pub const ROUND_NOT_COMPLETED: felt252 = 'Contribution: not completed';
    /// Error triggered when address is invalid
    pub const INVALID_ADDRESS: felt252 = 'Contribution: invalid';
    /// Error triggered when already a member
    pub const ALREADY_MEMBER: felt252 = 'Contribution: already member';
    /// Error triggered when caller is not owner
    pub const NOT_OWNER: felt252 = 'Contribution: not owner';
}

pub mod PaymentFlexibilityErrors {
    /// Error triggered when caller is not an Admin or higher
    pub const NOT_ADMIN: felt252 = 'Payment: not admin';
    /// Error triggered when auto-payment is disabled
    pub const AUTO_PAYMENT_DISABLED: felt252 = 'Payment: auto disabled';
    /// Error triggered when token is not supported
    pub const INVALID_TOKEN: felt252 = 'Payment: invalid token';
    /// Error triggered when amount is invalid
    pub const INVALID_AMOUNT: felt252 = 'Payment: invalid amount';
    /// Error triggered when payment not found
    pub const PAYMENT_NOT_FOUND: felt252 = 'Payment: not found';
    /// Error triggered when grace period expired
    pub const GRACE_PERIOD_EXPIRED: felt252 = 'Payment: grace expired';
    /// Error triggered when insufficient allowance
    pub const INSUFFICIENT_ALLOWANCE: felt252 = 'Payment: no allowance';
    /// Error triggered when oracle error occurs
    pub const ORACLE_ERROR: felt252 = 'Payment: oracle error';
    /// Error triggered when round not found
    pub const ROUND_NOT_FOUND: felt252 = 'Payment: round not found';
    /// Error triggered when auto-payment already active
    pub const AUTO_PAYMENT_ACTIVE: felt252 = 'Payment: already active';
    /// Error triggered when frequency is invalid
    pub const INVALID_FREQUENCY: felt252 = 'Payment: invalid frequency';
}

pub mod AnalyticsComponentErrors {
    /// Error triggered when caller is not an Admin or higher
    pub const NOT_ADMIN: felt252 = 'Analytics: not admin';
    /// Error triggered when analytics is disabled
    pub const ANALYTICS_DISABLED: felt252 = 'Analytics: disabled';
    /// Error triggered when member not found
    pub const MEMBER_NOT_FOUND: felt252 = 'Analytics: member not found';
    /// Error triggered when round not found
    pub const ROUND_NOT_FOUND: felt252 = 'Analytics: round not found';
    /// Error triggered when period is invalid
    pub const INVALID_PERIOD: felt252 = 'Analytics: invalid period';
    /// Error triggered when insufficient data
    pub const INSUFFICIENT_DATA: felt252 = 'Analytics: insufficient data';
}

pub mod MemberProfileComponentErrors {
    /// Error triggered when caller is not an Admin or higher
    pub const NOT_ADMIN: felt252 = 'MemberProfile: not admin';
    /// Error triggered when profile not found
    pub const PROFILE_NOT_FOUND: felt252 = 'MemberProfile: invalid profile';
    /// Error triggered when profile already exists
    pub const PROFILE_ALREADY_EXISTS: felt252 = 'MemberProfile: profile exists';
    /// Error triggered when rating is invalid
    pub const INVALID_RATING: felt252 = 'MemberProfile: invalid rating';
    /// Error triggered when preferences are invalid
    pub const INVALID_PREFERENCES: felt252 = 'MemberProfile: invalid pref';
    /// Error triggered when member not on waitlist
    pub const MEMBER_NOT_ON_WAITLIST: felt252 = 'MemberProfile: not on waitlist';
}
