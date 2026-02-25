# Governance Tollbooth

Governance Tollbooth is a Clarity smart contract that implements an on-chain proposal fee and evaluation system on the Stacks blockchain.

It enables a decentralized funding mechanism where citizens submit improvement proposals with collateral, curators stake backing support, and treasury rules determine proposal outcomes.

---

# Overview

Governance Tollbooth introduces a structured funding pipeline that ensures:

- Citizens commit collateral when submitting initiatives
- Curators compete by staking backing support
- Evaluation windows enforce decision timelines
- Treasury tax mechanisms apply automatically
- Administrative controls remain limited and capped

The contract provides deterministic governance mechanics using block-height based review windows and stake-weighted backing logic.

---

# Problem Statement

Open governance systems often face:

- Low-quality or spam proposals
- No economic alignment between reviewers and submitters
- No structured evaluation deadlines
- Lack of treasury sustainability mechanisms

Governance Tollbooth solves these by introducing collateral requirements, curator staking competition, and automated treasury taxation.

---

# Core Features

## 1. Proposal Submission

Citizens submit proposals including:

- proposal-title
- implementation-plan
- budget-breakdown
- review-window (in blocks)
- collateral-requirement

Each submission:

- Is indexed sequentially
- Opens an evaluation window
- Requires non-empty metadata fields
- Enforces minimum collateral requirements

---

## 2. Curator Backing Mechanism

Curators pledge support through stake-weighted backing:

- First pledge must meet or exceed collateral requirement
- Subsequent pledges must exceed current total backing
- Lead curator is dynamically updated
- Backing competition prevents passive approvals

This ensures only the strongest support leads the proposal.

---

## 3. Evaluation Window

Each proposal includes:

- submission-epoch
- review-cutoff
- evaluation-active flag

Rules:

- Backing allowed only before review-cutoff
- Citizen may conclude evaluation early
- Withdrawal allowed only if no backing exists

Block-height enforcement ensures deterministic governance timing.

---

## 4. Treasury Tax System

Treasury tax:

- Stored in basis points
- Default: 150 (1.5%)
- Maximum allowed: 1000 (10%)
- Adjustable only by treasury-guardian

Tax formula:

```
tax = (allocation * treasury-tax-rate) / 10000
```

Citizen allocation:

```
net = allocation - tax
```

---

# Contract Architecture

## Maps

### initiative-submissions

Stores:

- citizen-submitter
- proposal-title
- implementation-plan
- budget-breakdown
- submission-epoch
- review-cutoff
- collateral-requirement
- total-backing
- lead-curator
- evaluation-active
- funded

---

### curator-pledges

Stores:

- submission-index
- curator
- pledge-amount
- pledge-epoch

---

## Data Variables

- submission-nonce
- treasury-tax-rate
- treasury-guardian

---

# Public Functions

## Proposal Lifecycle

- file-proposal  
  Submit a new initiative proposal.

- pledge-support  
  Curator stakes backing support.

- conclude-evaluation  
  Citizen ends review window early.

- withdraw-proposal  
  Citizen cancels proposal if no backing exists.

---

## Administrative

- modify-treasury-tax  
  Adjust treasury tax rate (guardian only, capped at 10%).

---

## Read-Only Functions

- lookup-submission
- lookup-curator-pledge
- submission-recorded
- is-evaluation-window-open
- is-proposal-funded
- current-submission-index
- treasury-tax-bps
- compute-treasury-tax

---

# Error Codes

Error range: u300 – u315

Examples:

- ex-submission-missing
- ex-invalid-review-window
- ex-invalid-collateral
- ex-evaluation-concluded
- ex-not-citizen
- ex-guardian-only

Each error enforces deterministic contract safety.

---

# Governance Flow Summary

1. Citizen files proposal with collateral requirement.
2. Evaluation window opens.
3. Curators compete with backing pledges.
4. Highest backing becomes lead curator.
5. Citizen may conclude or withdraw if conditions allow.
6. Treasury tax applies to allocations.

---

# Security Properties

- Strict role validation
- Block-height enforced evaluation windows
- Competitive backing requirement
- Treasury tax cap enforcement
- Non-empty metadata validation
- Deterministic state transitions

---

# Future Improvements

- Slashing logic for abandoned initiatives
- Automated treasury disbursement logic
- Multi-tier curator roles
- Citizen reputation tracking
- On-chain milestone verification
