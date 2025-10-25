module {{sender}}::vault {

    use std::signer;
    use std::coin;
    use std::event;
    use std::error;
    use aptos_framework::aptos_coin::AptosCoin;

    /// Error codes
    const E_NOT_ADMIN: u64 = 1;
    const E_INSUFFICIENT_BALANCE: u64 = 2;
    const E_NOT_ALLOCATED: u64 = 3;

    /// Event emitted when tokens are deposited
    struct TokensDepositedEvent has copy, drop, store {
        amount: u64,
    }

    /// Event emitted when tokens are withdrawn
    struct TokensWithdrawnEvent has copy, drop, store {
        amount: u64,
    }

    /// Event emitted when tokens are allocated
    struct TokensAllocatedEvent has copy, drop, store {
        recipient: address,
        amount: u64,
    }

    /// Event emitted when tokens are claimed
    struct TokensClaimedEvent has copy, drop, store {
        recipient: address,
        amount: u64,
    }

    /// Vault resource holding balances, admin, and events
    struct Vault has key {
        admin: address,
        vault_address: address,
        total_balance: u64,
        allocations: table::Table<address, u64>,
        tokens_deposited_events: event::EventHandle<TokensDepositedEvent>,
        tokens_withdrawn_events: event::EventHandle<TokensWithdrawnEvent>,
        tokens_allocated_events: event::EventHandle<TokensAllocatedEvent>,
        tokens_claimed_events: event::EventHandle<TokensClaimedEvent>,
    }

    /// Initialize the vault
    public entry fun init_vault(admin: &signer, vault_address: address) {
        move_to(
            admin,
            Vault {
                admin: signer::address_of(admin),
                vault_address,
                total_balance: 0,
                allocations: table::new(),
                tokens_deposited_events: event::new_event_handle<TokensDepositedEvent>(admin),
                tokens_withdrawn_events: event::new_event_handle<TokensWithdrawnEvent>(admin),
                tokens_allocated_events: event::new_event_handle<TokensAllocatedEvent>(admin),
                tokens_claimed_events: event::new_event_handle<TokensClaimedEvent>(admin),
            }
        );
    }

    /// Deposit tokens directly using vault_address
    public entry fun deposit_tokens(admin: &signer, vault_address: address, amount: u64)
    acquires Vault {
        let vault = borrow_global_mut<Vault>(vault_address);
        assert!(vault.admin == signer::address_of(admin), error::invalid_argument(E_NOT_ADMIN));

        coin::transfer<AptosCoin>(admin, vault_address, amount);
        vault.total_balance = vault.total_balance + amount;

        event::emit_event(&mut vault.tokens_deposited_events, TokensDepositedEvent { amount });
    }

    /// Allocate tokens from admin to recipient
    public entry fun allocate_tokens(admin: &signer, vault_address: address, recipient: address, amount: u64)
    acquires Vault {
        let vault = borrow_global_mut<Vault>(vault_address);
        assert!(vault.admin == signer::address_of(admin), error::invalid_argument(E_NOT_ADMIN));

        let current_balance = vault.total_balance;
        assert!(current_balance >= amount, error::invalid_argument(E_INSUFFICIENT_BALANCE));

        vault.total_balance = current_balance - amount;
        table::add(&mut vault.allocations, recipient, amount);

        event::emit_event(&mut vault.tokens_allocated_events, TokensAllocatedEvent {
            recipient,
            amount,
        });
    }

    /// Claim allocated tokens
    public entry fun claim_tokens(user: &signer, vault_address: address)
    acquires Vault {
        let vault = borrow_global_mut<Vault>(vault_address);
        let user_address = signer::address_of(user);

        if (!table::contains(&vault.allocations, user_address)) {
            abort error::invalid_argument(E_NOT_ALLOCATED);
        };

        let amount = *table::borrow(&vault.allocations, user_address);
        table::remove(&mut vault.allocations, user_address);

        coin::transfer<AptosCoin>(&vault.vault_address, user_address, amount);

        event::emit_event(&mut vault.tokens_claimed_events, TokensClaimedEvent {
            recipient: user_address,
            amount,
        });
    }

    /// Withdraw unallocated tokens (admin only)
    public entry fun withdraw_tokens(admin: &signer, vault_address: address, amount: u64)
    acquires Vault {
        let vault = borrow_global_mut<Vault>(vault_address);
        assert!(vault.admin == signer::address_of(admin), error::invalid_argument(E_NOT_ADMIN));

        assert!(vault.total_balance >= amount, error::invalid_argument(E_INSUFFICIENT_BALANCE));

        coin::transfer<AptosCoin>(&vault.vault_address, signer::address_of(admin), amount);
        vault.total_balance = vault.total_balance - amount;

        event::emit_event(&mut vault.tokens_withdrawn_events, TokensWithdrawnEvent { amount });
    }

    /// Transfer ownership of the vault (Bonus)
    public entry fun transfer_ownership(admin: &signer, vault_address: address, new_admin: address)
    acquires Vault {
        let vault = borrow_global_mut<Vault>(vault_address);
        assert!(vault.admin == signer::address_of(admin), error::invalid_argument(E_NOT_ADMIN));
        vault.admin = new_admin;
    }

    /// View function to check total balance
    public fun get_total_balance(vault_address: address): u64 acquires Vault {
        borrow_global<Vault>(vault_address).total_balance
    }
}
