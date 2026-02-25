;; Governance Tollbooth: On-Chain Proposal Fee System
;; Decentralized funding mechanism featuring:
;; 1. Citizens submit improvement proposals with collateral
;; 2. Curators evaluate submission quality and stake backing
;; 3. Treasury releases funds for approved initiatives
;; 4. Automated slashing for rejected or abandoned proposals

(define-constant treasury-guardian tx-sender)

;; Exception states
(define-constant ex-insufficient-privileges (err u300))
(define-constant ex-submission-duplicate (err u301))
(define-constant ex-submission-missing (err u302))
(define-constant ex-proposal-settled (err u303))
(define-constant ex-review-pending (err u304))
(define-constant ex-evaluation-failed (err u305))
(define-constant ex-not-curator (err u306))
(define-constant ex-not-citizen (err u307))
(define-constant ex-already-evaluated (err u308))
(define-constant ex-invalid-review-window (err u309))
(define-constant ex-invalid-collateral (err u310))
(define-constant ex-guardian-only (err u311))
(define-constant ex-evaluation-concluded (err u312))
(define-constant ex-empty-proposal-title (err u313))
(define-constant ex-empty-implementation-plan (err u314))
(define-constant ex-empty-budget-breakdown (err u315))

;; Initiative submissions ledger
(define-map initiative-submissions
  { submission-index: uint }
  {
    citizen-submitter: principal,
    proposal-title: (string-ascii 64),
    implementation-plan: (string-ascii 256),
    budget-breakdown: (string-ascii 256),
    submission-epoch: uint,
    review-cutoff: uint,
    collateral-requirement: uint,
    total-backing: uint,
    lead-curator: (optional principal),
    evaluation-active: bool,
    funded: bool
  }
)

(define-map curator-pledges
  { submission-index: uint, curator: principal }
  { pledge-amount: uint, pledge-epoch: uint }
)

;; Submission index tracker
(define-data-var submission-nonce uint u1)

;; Treasury tax (1.5% = 150 basis points)
(define-data-var treasury-tax-rate uint u150)

;; View functions

(define-read-only (lookup-submission (submission-index uint))
  (map-get? initiative-submissions { submission-index: submission-index })
)

(define-read-only (lookup-curator-pledge (submission-index uint) (curator principal))
  (map-get? curator-pledges { submission-index: submission-index, curator: curator })
)

(define-read-only (submission-recorded (submission-index uint))
  (is-some (lookup-submission submission-index))
)

(define-read-only (is-evaluation-window-open (submission-index uint))
  (match (lookup-submission submission-index)
    submission-record (and 
                        (get evaluation-active submission-record)
                        (< block-height (get review-cutoff submission-record))
                      )
    false
  )
)

(define-read-only (current-submission-index)
  (var-get submission-nonce)
)

(define-read-only (treasury-tax-bps)
  (var-get treasury-tax-rate)
)

(define-read-only (compute-treasury-tax (allocation uint))
  (/ (* allocation (var-get treasury-tax-rate)) u10000)
)

;; Internal helpers

(define-private (calculate-citizen-allocation (allocation uint))
  (- allocation (compute-treasury-tax allocation))
)

(define-private (sanitize-proposal-title (title (string-ascii 64)))
  (> (len title) u0)
)

(define-private (sanitize-implementation-plan (plan (string-ascii 256)))
  (> (len plan) u0)
)

(define-private (sanitize-budget-breakdown (budget (string-ascii 256)))
  (> (len budget) u0)
)

;; Main operations

(define-public (file-proposal
                (proposal-title (string-ascii 64))
                (implementation-plan (string-ascii 256))
                (budget-breakdown (string-ascii 256))
                (review-window uint)
                (collateral-requirement uint))
  (let ((submission-index (var-get submission-nonce))
        (submission-epoch block-height)
        (review-cutoff (+ block-height review-window)))
    (begin
      (asserts! (sanitize-proposal-title proposal-title) ex-empty-proposal-title)
      (asserts! (sanitize-implementation-plan implementation-plan) ex-empty-implementation-plan)
      (asserts! (sanitize-budget-breakdown budget-breakdown) ex-empty-budget-breakdown)
      (asserts! (> review-window u0) ex-invalid-review-window)
      (asserts! (> collateral-requirement u0) ex-invalid-collateral)
      
      (map-set initiative-submissions
        { submission-index: submission-index }
        {
          citizen-submitter: tx-sender,
          proposal-title: proposal-title,
          implementation-plan: implementation-plan,
          budget-breakdown: budget-breakdown,
          submission-epoch: submission-epoch,
          review-cutoff: review-cutoff,
          collateral-requirement: collateral-requirement,
          total-backing: u0,
          lead-curator: none,
          evaluation-active: true,
          funded: false
        }
      )
      
      (var-set submission-nonce (+ submission-index u1))
      
      (ok submission-index)
    )
  )
)

(define-public (pledge-support (submission-index uint) (pledge-amount uint))
  (let ((submission-record (unwrap! (lookup-submission submission-index) ex-submission-missing)))
    (begin
      (asserts! (get evaluation-active submission-record) ex-evaluation-concluded)
      (asserts! (< block-height (get review-cutoff submission-record)) ex-proposal-settled)
      
      (asserts! (if (is-some (get lead-curator submission-record))
                   (> pledge-amount (get total-backing submission-record))
                   (>= pledge-amount (get collateral-requirement submission-record)))
               ex-evaluation-failed)
      
      (map-set curator-pledges
        { submission-index: submission-index, curator: tx-sender }
        { pledge-amount: pledge-amount, pledge-epoch: block-height }
      )
      
      (map-set initiative-submissions
        { submission-index: submission-index }
        (merge submission-record {
          total-backing: pledge-amount,
          lead-curator: (some tx-sender)
        })
      )
      
      (ok true)
    )
  )
)

(define-public (conclude-evaluation (submission-index uint))
  (let ((submission-record (unwrap! (lookup-submission submission-index) ex-submission-missing)))
    (begin
      (asserts! (is-eq tx-sender (get citizen-submitter submission-record)) ex-not-citizen)
      (asserts! (get evaluation-active submission-record) ex-evaluation-concluded)
      (asserts! (< block-height (get review-cutoff submission-record)) ex-proposal-settled)
      
      (map-set initiative-submissions
        { submission-index: submission-index }
        (merge submission-record {
          evaluation-active: false,
          review-cutoff: block-height
        })
      )
      
      (ok true)
    )
  )
)

(define-public (withdraw-proposal (submission-index uint))
  (let ((submission-record (unwrap! (lookup-submission submission-index) ex-submission-missing)))
    (begin
      (asserts! (is-eq tx-sender (get citizen-submitter submission-record)) ex-not-citizen)
      (asserts! (get evaluation-active submission-record) ex-evaluation-concluded)
      (asserts! (is-eq (get total-backing submission-record) u0) ex-evaluation-failed)
      
      (map-set initiative-submissions
        { submission-index: submission-index }
        (merge submission-record { evaluation-active: false })
      )
      
      (ok true)
    )
  )
)

;; Administrative functions

(define-public (modify-treasury-tax (new-tax-rate uint))
  (begin
    (asserts! (is-eq tx-sender treasury-guardian) ex-guardian-only)
    (asserts! (<= new-tax-rate u1000) ex-insufficient-privileges)
    (ok (var-set treasury-tax-rate new-tax-rate))
  )
)