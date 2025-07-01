pub mod base {
    pub mod errors;
    pub mod events;
    pub mod types;
}

pub mod interfaces {
    pub mod IERC20;
    pub mod IGovernance;
    pub mod IStarkRemit;
}

pub mod utils {
    pub mod constants;
    pub mod helpers;
}

pub mod starkremit {
    pub mod StarkRemit;
}

pub mod presets {
    pub mod ERC20;
}
