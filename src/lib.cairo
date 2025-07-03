pub mod Utils {
    pub mod Constants;
    pub mod Helpers;
}

pub mod Starkremit {
    pub mod StarkRemit;
}

pub mod presets {
    pub mod ERC20 {
        pub mod ERC20;
        pub mod IERC20;
    }
}

pub mod components {
    pub mod agent_management {
        pub mod AgentManagement;
        pub mod AgentManagementErrors;
        pub mod AgentManagementEvents;
        pub mod AgentManagementTypes;
        pub mod IAgentManagement;
    }
    pub mod kyc_management {
        pub mod IKYCManagement;
        pub mod KYCManagement;
        pub mod KYCManagementErrors;
        pub mod KYCManagementEvents;
        pub mod KYCManagementTypes;
    }
    pub mod loan_management {
        pub mod ILoanManagement;
        pub mod LoanManagement;
        pub mod LoanManagementErrors;
        pub mod LoanManagementEvents;
        pub mod LoanManagementTypes;
    }
    pub mod savings_group {
        pub mod ISavingsGroup;
        pub mod SavingsGroup;
        pub mod SavingsGroupErrors;
        pub mod SavingsGroupEvents;
        pub mod SavingsGroupTypes;
    }
    pub mod transfer_management {
        pub mod ITransferManagement;
        pub mod TransferManagement;
        pub mod TransferManagementErrors;
        pub mod TransferManagementEvents;
        pub mod TransferManagementTypes;
    }
    pub mod user_management {
        pub mod IUserManagement;
        pub mod UserManagement;
        pub mod UserManagementErrors;
        pub mod UserManagementEvents;
        pub mod UserManagementTypes;
    }
}
