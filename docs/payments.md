# Payment and settlement design

## Provider selection

Evaluate Cashfree and Easebuzz against current pricing, authorization success, refund and dispute workflows, support, uptime, and the exact marketplace/seller-settlement product available to the merchant. A standard payment checkout is not automatically a split-settlement product. Get written confirmation of marketplace eligibility, seller onboarding/KYC requirements, supported split instructions, settlement timing, fees, and refund/reversal behavior before integrating.

Provider API contracts and payment-mode availability change. Validate current official documentation and sandbox behavior during implementation. Enable only payment methods actually approved and returned for this merchant configuration: UPI Intent/QR, eligible RuPay/Visa/Mastercard credit/debit cards, net banking, and supported wallets (for example Paytm, MobiKwik, or Amazon Pay where offered). Do not promise every method on every device or transaction.

## UPI split-payment sequence

```mermaid
sequenceDiagram
    actor Buyer
    participant UI as Storefront
    participant API as Marketplace API
    participant DB as PostgreSQL
    participant PSP as PSP marketplace API
    participant App as UPI app / QR
    participant Seller as Seller settlement account

    Buyer->>UI: Confirm cart and choose UPI
    UI->>API: Create checkout (authenticated, idempotency key)
    API->>DB: Transaction: validate price/stock, reserve inventory, create pending order + seller orders + ledger quote
    API->>PSP: Create payment/order with marketplace split instructions
    PSP-->>API: Provider order reference + checkout/UPI Intent or QR data
    API-->>UI: Checkout session (no secret credentials)
    UI-->>Buyer: Launch UPI Intent or render QR
    Buyer->>App: Approve payment in UPI app
    App->>PSP: Authorize payment
    PSP-->>API: Signed webhook (may be retried or delayed)
    API->>API: Verify signature, timestamp/replay rules; fetch authoritative status if needed
    API->>DB: Idempotent transaction: record event/payment, confirm order, finalize stock and split ledger
    API-->>UI: Client polls order/payment status
    PSP->>Seller: Settle seller net per approved schedule
    PSP-->>API: Settlement/report event or reconciliation data
    API->>DB: Reconcile transfer reference, fee, net and settlement status
```

## Required invariants

1. Calculate the amount and seller allocations on the server from persisted order data; never accept the commission, seller net, or payment success flag from the client.
2. Use an idempotency key for checkout creation and webhook event IDs for provider notifications. Persist provider references with uniqueness constraints.
3. Treat webhook delivery as at-least-once. Verify provider signatures exactly as documented, deduplicate, and transition payment/order state through allowed transitions only.
4. Use a payment status query/reconciliation path for missing webhooks and uncertain outcomes. The browser return URL is never proof of payment.
5. Commit payment/order/ledger/inventory state atomically. Publish notifications and fulfillment events through a transactional outbox or durable equivalent.
6. Define reservation timeout, failed-payment release, partial fulfillment, cancellation, partial refund, full refund, chargeback, and settlement reversal paths before launch.
7. Record amounts as integer paise and snapshot the chosen commission rate. Example: 300 basis points is 3%; the commercial/tax definition of the fee base must be agreed explicitly.

## Split routing and compliance

The intended routing is customer charge -> PSP-managed marketplace collection -> platform commission allocation and seller net allocation -> PSP settlement to onboarded seller accounts. Use only the provider's approved marketplace/split product and API semantics; do not emulate settlement by collecting funds and manually transferring them unless the provider and advisers explicitly approve that arrangement.

Persist expected allocations in `commission_splits`, but reconcile actual settlement reports rather than assuming a successful payment means the seller has already been paid. Track PSP fees, tax withholding/deductions (if applicable), reserves, refunds, reversals, and discrepancies as explicit ledger events. Do not store seller bank credentials; keep only the opaque PSP seller-account reference.
