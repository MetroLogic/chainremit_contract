

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