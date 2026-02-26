# Payment Gateway - CALM Architecture Example

A sample [CALM (Common Architecture Language Model)](https://github.com/finos/architecture-as-code) architecture definition for a **PCI-DSS compliant payment gateway**. This repo demonstrates how to model a real-world payment processing system — its components, connections, data flows, and security controls — as a machine-readable `.calm.json` file.

## What is CALM?

CALM is a declarative specification format for defining software architectures. Instead of drawing diagrams in a tool, you describe your architecture in structured JSON that is both human-readable and machine-parsable. This enables:

- **Automated compliance checking** — validate that security controls are defined and mapped to standards
- **Architecture governance** — enforce patterns and policies across teams
- **Living documentation** — the architecture spec stays in version control alongside code
- **Tooling integration** — generate diagrams, reports, and audits from the same source of truth

## Repository Structure

```
payment-gateway-calm/
├── payment-gateway.calm.json   # The CALM architecture definition
├── LICENSE                     # Apache 2.0
└── README.md
```

The entire architecture is defined in a single file: **`payment-gateway.calm.json`**.

## Architecture Overview

The system models a secure payment flow from customer checkout through card authorization and transaction recording.

```
                          ┌─────────────────────────────────────────────────┐
  ┌──────────┐            │              Core Services                      │
  │ Customer │            │                                                 │
  └────┬─────┘            │  ┌───────────────┐    ┌──────────────────────┐  │   ┌──────────────┐
       │ 1.               │  │  Cardholder   │    │  Tokenization Svc    │──┼──▶│ Card Network  │
       ▼                  │  │  Data (asset)  │    │  (RESTRICTED)       │  │   │ (Visa/MC)    │
  ┌──────────┐   2.HTTPS  │  └───────────────┘    └──────────────────────┘  │   └──────────────┘
  │ Checkout │───────────▶│  ┌──────────────────────────────────┐           │         5. mTLS
  │  Page    │            │  │         Payment API               │           │
  └──────────┘            │  │  (orchestrator)                   │───────────┼──▶┌──────────────┐
                          │  └────────┬─────────────────────────┘           │   │ Transaction  │
                          │           │ 3. HTTPS                            │   │ Database     │
                          │           ▼                                     │   │(CONFIDENTIAL)│
                          │  ┌──────────────────┐                           │   └──────────────┘
                          │  │ Fraud Detection   │                           │         6. JDBC
                          │  │ (ML scoring)      │                           │
                          │  └──────────────────┘                           │
                          └─────────────────────────────────────────────────┘
```

## How the Code Maps to CALM

The `.calm.json` file has three top-level sections that map directly to CALM's core concepts:

### 1. `nodes` — System Components

Each component in the architecture is a **node** with a type, name, and optional security controls.

| Node ID | CALM Node Type | Description | Data Classification |
|---------|---------------|-------------|---------------------|
| `customer` | `actor` | End user making a payment | — |
| `checkout-page` | `webclient` | PCI-DSS compliant payment form | — |
| `payment-api` | `service` | Orchestrates tokenization, fraud, and authorization | — |
| `tokenization-service` | `service` | Replaces card data with tokens (AES-256) | RESTRICTED |
| `fraud-detection` | `service` | ML-based fraud scoring engine | — |
| `transaction-database` | `database` | Payment records with encryption and audit trails | CONFIDENTIAL |
| `card-network` | `system` | External Visa/Mastercard network | — |
| `cardholder-data` | `data-asset` | PCI-DSS scoped data (PAN, CVV, expiration) | RESTRICTED |

### 2. `relationships` — Connections Between Components

Each connection specifies how two nodes communicate, including the protocol and any security controls on the link itself.

| Relationship ID | Type | From | To | Protocol |
|----------------|------|------|----|----------|
| `customer-to-checkout` | `interacts` | Customer | Checkout Page | — |
| `checkout-to-payment-api` | `connects` | Checkout Page | Payment API | HTTPS |
| `payment-api-to-tokenization` | `connects` | Payment API | Tokenization Service | mTLS |
| `payment-api-to-fraud` | `connects` | Payment API | Fraud Detection | HTTPS |
| `payment-api-to-db` | `connects` | Payment API | Transaction Database | JDBC |
| `tokenization-to-card-network` | `connects` | Tokenization Service | Card Network | mTLS |

### 3. `flows` — End-to-End Data Flows

Flows compose relationships into ordered sequences that describe business processes.

**Payment Processing Flow** — the complete path from card entry to transaction recording:

| Step | Transition | Description |
|------|-----------|-------------|
| 1 | `customer-to-checkout` | Customer enters card details on checkout page |
| 2 | `checkout-to-payment-api` | Checkout submits encrypted payment to API |
| 3 | `payment-api-to-fraud` | Payment API checks fraud score |
| 4 | `payment-api-to-tokenization` | Payment API requests card tokenization |
| 5 | `tokenization-to-card-network` | Tokenization service authorizes with card network |
| 6 | `payment-api-to-db` | Payment API records the transaction |

## Security Controls

Each node and relationship can define **controls** — security requirements mapped to compliance standards. This is where CALM shines for governance and audit.

| Component | Control | Standard | Description |
|-----------|---------|----------|-------------|
| Checkout Page | `input-validation` | PCI-DSS | Client-side card format and CVV validation |
| Checkout Page | `secure-transmission` | PCI-DSS | TLS 1.2+ for all payment data |
| Payment API | `pci-dss-compliance` | PCI-DSS | SAQ-D compliant with annual assessment |
| Payment API | `api-authentication` | OWASP | API key auth, rate limiting, IP whitelisting |
| Tokenization Service | `encryption-at-rest` | PCI-DSS | AES-256 for stored card data in vault |
| Tokenization Service | `key-management` | NIST SP 800-57 | HSM-based keys rotated every 90 days |
| Tokenization Service | `access-logging` | PCI-DSS | Audit logging with tamper detection |
| Transaction Database | `data-encryption` | PCI-DSS | Transparent encryption for all records |
| Transaction Database | `audit-logging` | PCI-DSS | Audit trail for all access |
| Transaction Database | `data-retention` | Visa Standards | 3-year retention, secure deletion |
| Fraud Detection | `model-monitoring` | ISO 27001 | Quarterly retraining on new fraud patterns |
| Cardholder Data | `data-minimization` | PCI-DSS | Minimum data collection, never store CVV |
| Checkout-to-API link | `tls-enforcement` | PCI-DSS | TLS 1.2 minimum with strong cipher suites |

## Getting Started

### Validate with the CALM CLI

```bash
npm install -g @finos/calm-cli
calm validate -p payment-gateway.calm.json
```

### Generate a visualization

```bash
calm visualize -i payment-gateway.calm.json
```

## License

Apache 2.0 — see [LICENSE](LICENSE).
