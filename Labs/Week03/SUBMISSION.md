# Lab 4 Submission Checklist

Google Form fields to fill out:

- [ ] **Email**: bm9353@princeton.edu

- [ ] **Etherscan LINK to any of your single swap transactions with Uniswap**
  - https://sepolia.etherscan.io/tx/0x331dd921e3357c5ce9dd394d119568e5d821c72f79ce51365aed8088a94783fc
  - (Success — swapped 1 TIGER → 0.99608608 LUSD)

- [ ] **Etherscan LINK to any of your atomic swap transactions with Uniswap**
  - https://sepolia.etherscan.io/tx/0xeedfa19a75df476edc64d40c0700fbce878a2aa81e84d4bbf3f13fba0aaf7eae
  - (Success — replaces the earlier atomic swap hash, which had actually
    reverted on-chain with error `STF`; see notes below)

- [x] **What is the purpose of calling the "approve()" function? Explain in 1-2
      sentences.**
  - ERC-20 tokens only let the token owner move their own balance directly; any
    other contract (like Uniswap's router) can only transfer tokens on your
    behalf if you've explicitly authorized it. Calling `approve()` grants the
    router permission to pull up to a specified amount of your tokens, which is
    required before it can execute a swap for you.

- [x] **In the code, print and see the amountIn. Compare it with the amount of
      token deduced from your account. Is there a difference? If so, why?**
  - For the single swap, `amountIn` was `w3.to_wei(1, 'ether')` (1 TIGER), and
    the actual TIGER balance deducted from the account was also exactly 1 TIGER
    (confirmed via the Transfer event on Etherscan). There is no difference on
    the input side: `exactInputSingle` transfers precisely the amount you
    specify, since TIGER is a standard ERC-20 with no transfer tax. The swap's
    cost instead shows up on the _output_ side — you received 0.99608608 LUSD
    instead of a full 1, which reflects the pool's swap fee (0.05% fee tier)
    plus price impact, not any deduction from `amountIn` itself. Gas is a
    separate cost paid in ETH, not in the swapped token, so it never affects the
    token balance change.

- [x] **Open your atomic transaction on Etherscan and report the exact amount of
      exchanged tokens.**
  - Atomic tx:
    https://sepolia.etherscan.io/tx/0xeedfa19a75df476edc64d40c0700fbce878a2aa81e84d4bbf3f13fba0aaf7eae
  - Leg 1 (LUSD → TIGER): sent 1.0 LUSD, received 1.0124786177771985 TIGER
  - Leg 2 (TIGER → LUSD): sent 0.5 TIGER, received 0.4933690078674528 LUSD

## Notes on what went wrong / was fixed

- The atomic swap cell (26) originally tried TIGER→LUSD first using a full
  1-TIGER amount, but by that point in the notebook the single swap (cell 22)
  had already spent the entire TIGER balance (1 → 0). That made the first leg
  fail with Uniswap's `STF` ("SafeTransferFrom failed") error, reverting the
  whole multicall — even though `send_raw_transaction` returned a tx hash with
  no client-side error, so it initially looked like it had succeeded.
- Fixed by swapping the leg order (LUSD→TIGER first, since LUSD was the token
  actually held) and sizing the second leg (0.5 TIGER) safely below what the
  first leg would return, so the second transfer can never exceed the account's
  balance.
- Before submitting, double check both links above still show "Success" on
  **Sepolia** Etherscan (not mainnet) — Etherscan can take a minute to fully
  index token transfers after a transaction confirms.
