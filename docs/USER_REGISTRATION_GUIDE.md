# StarkRemit User Registration System

## Overview

The StarkRemit platform includes a comprehensive user onboarding and registration system that allows new users to create accounts, manage their profiles, and undergo KYC verification. This document provides detailed information about the registration functionality, API usage, and integration guidelines.

## Features

### Core Registration Features
- **User Registration**: Create new user accounts with validated personal information
- **Duplicate Prevention**: Prevent multiple registrations with the same email or phone number
- **Data Validation**: Comprehensive validation of all user input data
- **Event Logging**: Complete audit trail of all registration activities
- **Profile Management**: Update and maintain user profile information
- **KYC System**: Multi-level KYC verification system
- **Admin Controls**: Administrative functions for user management

### Registration Data Structure

```cairo
#[derive(Copy, Drop, Serde)]
pub struct RegistrationRequest {
    pub email_hash: felt252,     // Hashed email for privacy
    pub phone_hash: felt252,     // Hashed phone number for privacy
    pub full_name: felt252,      // User's full name
    pub preferred_currency: felt252, // User's preferred currency
    pub country_code: felt252,   // User's country code
}

#[derive(Copy, Drop, Serde, starknet::Store)]
pub struct UserProfile {
    pub address: ContractAddress,        // User's wallet address
    pub email_hash: felt252,            // Email hash for uniqueness
    pub phone_hash: felt252,            // Phone hash for uniqueness
    pub full_name: felt252,             // Full name
    pub preferred_currency: felt252,     // Preferred currency
    pub kyc_level: KYCLevel,            // KYC verification level
    pub registration_timestamp: u64,     // Registration time
    pub is_active: bool,                // Account status
    pub country_code: felt252,          // Country code
}
```

### KYC Verification Levels

```cairo
pub enum KYCLevel {
    None,      // No verification completed
    Basic,     // Email and phone verified
    Advanced,  // ID documents verified
    Full,      // Complete verification including address proof
}
```

### Registration Status Tracking

```cairo
pub enum RegistrationStatus {
    NotStarted,  // User hasn't begun registration
    InProgress,  // Registration in progress
    Completed,   // Registration successfully completed
    Failed,      // Registration failed validation
    Suspended,   // Account suspended by admin
}
```

## API Reference

### User Registration Functions

#### `register_user(registration_data: RegistrationRequest) -> bool`
Register a new user with the platform.

**Parameters:**
- `registration_data`: Complete registration information

**Returns:** `true` if registration successful

**Validation Rules:**
- All fields must be non-empty (not 0)
- Email hash must be unique across the platform
- Phone hash must be unique across the platform
- Preferred currency must be supported by the platform
- Caller address cannot be zero address
- User cannot already be registered

**Events Emitted:**
- `UserRegistered` with user details

**Example Usage:**
```cairo
let registration_data = RegistrationRequest {
    email_hash: 'hashed_email_value',
    phone_hash: 'hashed_phone_value',
    full_name: 'John Doe',
    preferred_currency: 'USD',
    country_code: 'US',
};

let success = contract.register_user(registration_data);
```

#### `get_user_profile(user_address: ContractAddress) -> UserProfile`
Retrieve a user's complete profile information.

**Parameters:**
- `user_address`: The wallet address of the user

**Returns:** Complete `UserProfile` struct

**Requirements:**
- User must be registered and have status `Completed`

#### `update_user_profile(updated_profile: UserProfile) -> bool`
Update user profile information (user can only update their own profile).

**Parameters:**
- `updated_profile`: Updated profile information

**Returns:** `true` if update successful

**Restrictions:**
- Only the profile owner can update their profile
- Address and registration timestamp cannot be changed
- Email and phone changes must maintain uniqueness
- New preferred currency must be supported

**Events Emitted:**
- `UserProfileUpdated`

#### `is_user_registered(user_address: ContractAddress) -> bool`
Check if a user is registered and active.

**Parameters:**
- `user_address`: User's wallet address

**Returns:** `true` if user is registered with `Completed` status

#### `get_registration_status(user_address: ContractAddress) -> RegistrationStatus`
Get the current registration status of a user.

**Parameters:**
- `user_address`: User's wallet address

**Returns:** Current `RegistrationStatus`

#### `validate_registration_data(registration_data: RegistrationRequest) -> bool`
Validate registration data without creating an account.

**Parameters:**
- `registration_data`: Data to validate

**Returns:** `true` if all validation rules pass

### Administrative Functions

#### `update_kyc_level(user_address: ContractAddress, kyc_level: KYCLevel) -> bool`
Update a user's KYC verification level (admin only).

**Parameters:**
- `user_address`: Target user's address
- `kyc_level`: New KYC level

**Returns:** `true` if update successful

**Requirements:**
- Caller must be contract admin
- User must be registered

**Events Emitted:**
- `KYCLevelUpdated` with old and new levels

#### `deactivate_user(user_address: ContractAddress) -> bool`
Deactivate a user account (admin only).

**Parameters:**
- `user_address`: User to deactivate

**Returns:** `true` if deactivation successful

**Effects:**
- Sets user status to `Suspended`
- Sets `is_active` to `false`

**Events Emitted:**
- `UserDeactivated`

#### `reactivate_user(user_address: ContractAddress) -> bool`
Reactivate a suspended user account (admin only).

**Parameters:**
- `user_address`: User to reactivate

**Returns:** `true` if reactivation successful

**Events Emitted:**
- `UserReactivated`

#### `get_total_users() -> u256`
Get the total number of registered users.

**Returns:** Total user count

## Integration Guide

### Frontend Integration

#### 1. Data Preparation
Before calling the registration function, prepare user data:

```javascript
// Hash sensitive data on frontend before sending
const emailHash = hashFunction(userEmail);
const phoneHash = hashFunction(userPhoneNumber);

const registrationData = {
    email_hash: emailHash,
    phone_hash: phoneHash,
    full_name: convertToFelt252(userName),
    preferred_currency: convertToFelt252('USD'),
    country_code: convertToFelt252(userCountry)
};
```

#### 2. Registration Flow
```javascript
// Step 1: Validate data locally
const isValid = await contract.validate_registration_data(registrationData);
if (!isValid) {
    throw new Error('Invalid registration data');
}

// Step 2: Check if user is already registered
const isRegistered = await contract.is_user_registered(userAddress);
if (isRegistered) {
    throw new Error('User already registered');
}

// Step 3: Register user
try {
    const result = await contract.register_user(registrationData);
    if (result) {
        console.log('Registration successful');
        // Redirect to dashboard or next step
    }
} catch (error) {
    // Handle specific errors
    if (error.message.includes('Email already exists')) {
        showError('Email already registered');
    } else if (error.message.includes('Phone already exists')) {
        showError('Phone number already registered');
    }
    // ... handle other errors
}
```

#### 3. Profile Management
```javascript
// Get user profile
const profile = await contract.get_user_profile(userAddress);

// Update profile
const updatedProfile = {
    ...profile,
    full_name: convertToFelt252(newFullName),
    preferred_currency: convertToFelt252(newCurrency)
};

await contract.update_user_profile(updatedProfile);
```

### Backend Integration

#### Event Monitoring
Monitor registration events for analytics and compliance:

```cairo
// Events to monitor
event UserRegistered {
    user_address: ContractAddress,
    email_hash: felt252,
    preferred_currency: felt252,
    registration_timestamp: u64,
}

event UserProfileUpdated {
    user_address: ContractAddress,
    updated_fields: felt252,
}

event KYCLevelUpdated {
    user_address: ContractAddress,
    old_level: KYCLevel,
    new_level: KYCLevel,
    admin: ContractAddress,
}
```

## Security Considerations

### Data Privacy
- **Email and Phone Hashing**: Always hash email and phone data before storing
- **Off-chain Storage**: Consider storing detailed personal information off-chain
- **Access Control**: Implement proper access controls for sensitive operations

### Validation Security
- **Input Sanitization**: Validate all inputs on both frontend and smart contract
- **Duplicate Prevention**: The system prevents duplicate registrations
- **Admin Controls**: Admin functions are properly protected

### Compliance
- **KYC Integration**: Implement proper KYC verification workflows
- **Data Protection**: Ensure compliance with data protection regulations
- **Audit Trail**: All operations are logged via events

## Error Handling

### Common Errors and Solutions

| Error | Cause | Solution |
|-------|-------|----------|
| `User already registered` | Attempting to register an existing user | Check registration status first |
| `Email already exists` | Email hash collision | Use different email address |
| `Phone already exists` | Phone hash collision | Use different phone number |
| `Incomplete registration data` | Missing required fields | Validate all fields are populated |
| `Unsupported currency` | Invalid preferred currency | Use supported currency codes |
| `Zero address not allowed` | Invalid wallet address | Ensure valid wallet connection |
| `ERC20: not admin` | Non-admin calling admin function | Use admin account for admin operations |

### Best Practices

1. **Pre-validation**: Always validate data before blockchain calls
2. **Error Feedback**: Provide clear error messages to users
3. **Progressive Registration**: Consider multi-step registration for better UX
4. **State Management**: Track registration progress on frontend
5. **Retry Logic**: Implement retry mechanisms for network issues

## Testing

### Unit Tests
The system includes comprehensive tests covering:
- Successful registration flow
- Duplicate prevention (address, email, phone)
- Data validation
- KYC level management
- User activation/deactivation
- Admin function authorization
- Event emission verification

### Integration Testing
Test the complete flow:
1. User data collection
2. Data validation
3. Registration submission
4. Profile retrieval
5. Profile updates
6. KYC progression

## Deployment Checklist

- [ ] Deploy contract with proper admin configuration
- [ ] Set up supported currencies
- [ ] Configure oracle for exchange rates
- [ ] Test registration flow end-to-end
- [ ] Verify event monitoring setup
- [ ] Implement error handling in frontend
- [ ] Set up compliance monitoring
- [ ] Configure admin access controls

## Support and Troubleshooting

### Registration Issues
1. **Check prerequisites**: Ensure user has valid wallet connection
2. **Validate data**: Verify all required fields are properly formatted
3. **Check duplicates**: Ensure email/phone haven't been used before
4. **Verify currency**: Confirm preferred currency is supported
5. **Admin verification**: For admin functions, ensure proper permissions

### Performance Optimization
- Batch operations where possible
- Cache user profiles for frequent access
- Use events for real-time updates
- Implement pagination for user lists

For additional support, refer to the contract documentation or contact the development team. 