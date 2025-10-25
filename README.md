
# 🏦 Aptos Vault Smart Contract 

This project is part of the **Aptos Move Smart Contract Homework**, where we improved the efficiency of the Vault contract by removing redundant address derivations and directly using the `vault_address`.

---

## 🚀 Overview

The Vault smart contract manages secure token deposits, allocations, claims, and withdrawals in a controlled way under an admin account.  
This modified version enhances **efficiency and clarity** by:

- Removing the unnecessary `get_vault_address()` function.
- Passing `vault_address` directly to all core functions.
- Ensuring strong access control using:
  ```move
  assert!(vault.admin == signer::address_of(admin), E_NOT_ADMIN);
