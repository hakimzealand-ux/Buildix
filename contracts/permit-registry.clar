;; permit-registry.clar
;; Buildix - Blockchain Building Permit Registry
;; No cross-contract calls, no traits. Clarity v3 compatible.

;; -----------------------------
;; Constants and Errors
;; -----------------------------
(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-NOT-FOUND (err u101))
(define-constant ERR-ALREADY-EXISTS (err u102))
(define-constant ERR-INVALID-STATUS (err u103))
(define-constant ERR-INVALID-PARAM (err u104))
(define-constant ERR-EXPIRED (err u105))

(define-constant STATUS-PENDING u1)
(define-constant STATUS-APPROVED u2)
(define-constant STATUS-DENIED u3)
(define-constant STATUS-REVOKED u4)
(define-constant STATUS-EXPIRED u5)

;; -----------------------------
;; Data Variables
;; -----------------------------
(define-data-var contract-admin principal tx-sender)
(define-data-var next-permit-id uint u1)
(define-data-var total-permits uint u0)

;; Track per-applicant counts for indexing
(define-data-var next-applicant-index uint u1)

;; -----------------------------
;; Data Maps
;; -----------------------------
;; Authorities allowed to approve/deny/renew/revoke
(define-map authorities
  { addr: principal }
  {
    name: (string-ascii 100),
    jurisdiction: (string-ascii 100),
    active: bool,
    created-at: uint
  }
)

;; Main permits map
(define-map permits
  { permit-id: uint }
  {
    property-address: (string-ascii 200),
    permit-type: (string-ascii 50),
    applicant: principal,
    authority: (optional principal),
    issue-date: (optional uint),
    expiry-date: (optional uint),
    status: uint,
    description: (string-ascii 280),
    estimated-value: uint,
    created-at: uint,
    updated-at: uint
  }
)

;; Secondary index: permits by applicant
;; We store a sequential index for each applicant: (applicant, idx) -> permit-id
(define-map permits-by-applicant
  { applicant: principal, idx: uint }
  {
    permit-id: uint
  }
)

;; Maintain count per applicant
(define-map applicant-permit-count
  { applicant: principal }
  {
    count: uint
  }
)

;; Secondary index: permits by address (address + incremental index)
(define-map permits-by-address
  { property-address: (string-ascii 200), idx: uint }
  {
    permit-id: uint
  }
)

(define-map address-permit-count
  { property-address: (string-ascii 200) }
  {
    count: uint
  }
)

;; -----------------------------
;; Helpers
;; -----------------------------
(define-private (is-admin (who principal))
  (is-eq who (var-get contract-admin))
)

(define-private (is-authority (who principal))
  (match (map-get? authorities { addr: who })
    auth (get active auth)
    false
  )
)

(define-private (ensure-active-authority (who principal))
  (if (is-authority who) true false)
)

(define-private (now)
  stacks-block-height
)

(define-private (put-permit-indexes (permit-id uint) (applicant principal) (property-address (string-ascii 200)))
  (let (
    (app-count (default-to { count: u0 } (map-get? applicant-permit-count { applicant: applicant })))
    (new-idx (+ (get count app-count) u1))
    (addr-count (default-to { count: u0 } (map-get? address-permit-count { property-address: property-address })))
    (new-addr-idx (+ (get count addr-count) u1))
  )
    (map-set permits-by-applicant { applicant: applicant, idx: new-idx } { permit-id: permit-id })
    (map-set applicant-permit-count { applicant: applicant } { count: new-idx })
    (map-set permits-by-address { property-address: property-address, idx: new-addr-idx } { permit-id: permit-id })
    (map-set address-permit-count { property-address: property-address } { count: new-addr-idx })
    true
  )
)

;; -----------------------------
;; Authority Management
;; -----------------------------
(define-public (register-authority (addr principal) (name (string-ascii 100)) (jurisdiction (string-ascii 100)))
  (begin
    (asserts! (is-admin tx-sender) ERR-NOT-AUTHORIZED)
    (asserts! (> (len name) u0) ERR-INVALID-PARAM)
    (asserts! (> (len jurisdiction) u0) ERR-INVALID-PARAM)
    (asserts! (is-none (map-get? authorities { addr: addr })) ERR-ALREADY-EXISTS)
    (map-set authorities { addr: addr }
      {
        name: name,
        jurisdiction: jurisdiction,
        active: true,
        created-at: (now)
      }
    )
    (ok true)
  )
)

(define-public (set-authority-active (addr principal) (active bool))
  (let ((auth (unwrap! (map-get? authorities { addr: addr }) ERR-NOT-FOUND)))
    (asserts! (is-admin tx-sender) ERR-NOT-AUTHORIZED)
    (map-set authorities { addr: addr } (merge auth { active: active }))
    (ok active)
  )
)

;; -----------------------------
;; Permit Lifecycle
;; -----------------------------
(define-public (submit-permit-application
  (property-address (string-ascii 200))
  (permit-type (string-ascii 50))
  (description (string-ascii 280))
  (estimated-value uint)
  (expiry-date uint)
)
  (begin
    (asserts! (> (len property-address) u0) ERR-INVALID-PARAM)
    (asserts! (> (len permit-type) u0) ERR-INVALID-PARAM)
    (asserts! (> expiry-date (now)) ERR-INVALID-PARAM)
    (let (
      (pid (var-get next-permit-id))
      (created (now))
    )
      (map-set permits { permit-id: pid }
        {
          property-address: property-address,
          permit-type: permit-type,
          applicant: tx-sender,
          authority: none,
          issue-date: none,
          expiry-date: (some expiry-date),
          status: STATUS-PENDING,
          description: description,
          estimated-value: estimated-value,
          created-at: created,
          updated-at: created
        }
      )
      (put-permit-indexes pid tx-sender property-address)
      (var-set total-permits (+ (var-get total-permits) u1))
      (var-set next-permit-id (+ pid u1))
      (ok pid)
    )
  )
)

(define-public (approve-permit (permit-id uint) (authority principal) (issue-date uint))
  (let ((p (unwrap! (map-get? permits { permit-id: permit-id }) ERR-NOT-FOUND)))
(asserts! (ensure-active-authority authority) ERR-NOT-AUTHORIZED)
    (asserts! (is-eq tx-sender authority) ERR-NOT-AUTHORIZED)
    (asserts! (is-eq (get status p) STATUS-PENDING) ERR-INVALID-STATUS)
    (asserts! (>= issue-date (get created-at p)) ERR-INVALID-PARAM)
    (map-set permits { permit-id: permit-id }
      (merge p {
        authority: (some authority),
        issue-date: (some issue-date),
        status: STATUS-APPROVED,
        updated-at: (now)
      })
    )
    (ok true)
  )
)

(define-public (deny-permit (permit-id uint) (authority principal))
  (let ((p (unwrap! (map-get? permits { permit-id: permit-id }) ERR-NOT-FOUND)))
(asserts! (ensure-active-authority authority) ERR-NOT-AUTHORIZED)
    (asserts! (is-eq tx-sender authority) ERR-NOT-AUTHORIZED)
    (asserts! (is-eq (get status p) STATUS-PENDING) ERR-INVALID-STATUS)
    (map-set permits { permit-id: permit-id }
      (merge p {
        authority: (some authority),
        status: STATUS-DENIED,
        updated-at: (now)
      })
    )
    (ok true)
  )
)

(define-public (renew-permit (permit-id uint) (authority principal) (new-expiry uint))
  (let ((p (unwrap! (map-get? permits { permit-id: permit-id }) ERR-NOT-FOUND)))
(asserts! (ensure-active-authority authority) ERR-NOT-AUTHORIZED)
    (asserts! (is-eq tx-sender authority) ERR-NOT-AUTHORIZED)
    (asserts! (is-eq (get status p) STATUS-APPROVED) ERR-INVALID-STATUS)
    (asserts! (> new-expiry (default-to u0 (get expiry-date p))) ERR-INVALID-PARAM)
    (map-set permits { permit-id: permit-id }
      (merge p {
        expiry-date: (some new-expiry),
        updated-at: (now)
      })
    )
    (ok true)
  )
)

(define-public (revoke-permit (permit-id uint) (authority principal))
  (let ((p (unwrap! (map-get? permits { permit-id: permit-id }) ERR-NOT-FOUND)))
(asserts! (ensure-active-authority authority) ERR-NOT-AUTHORIZED)
    (asserts! (is-eq tx-sender authority) ERR-NOT-AUTHORIZED)
    (asserts! (or (is-eq (get status p) STATUS-APPROVED) (is-eq (get status p) STATUS-PENDING)) ERR-INVALID-STATUS)
    (map-set permits { permit-id: permit-id }
      (merge p {
        status: STATUS-REVOKED,
        updated-at: (now)
      })
    )
    (ok true)
  )
)

(define-public (expire-permit (permit-id uint))
  (let ((p (unwrap! (map-get? permits { permit-id: permit-id }) ERR-NOT-FOUND)))
    (let ((exp (default-to u0 (get expiry-date p))))
      (asserts! (> exp u0) ERR-INVALID-PARAM)
      (asserts! (> (now) exp) ERR-EXPIRED)
      (map-set permits { permit-id: permit-id }
        (merge p {
          status: STATUS-EXPIRED,
          updated-at: (now)
        })
      )
      (ok true)
    )
  )
)

;; Applicant can update description and estimated value while pending
(define-public (update-application (permit-id uint) (description (string-ascii 280)) (estimated-value uint))
  (let ((p (unwrap! (map-get? permits { permit-id: permit-id }) ERR-NOT-FOUND)))
    (asserts! (is-eq tx-sender (get applicant p)) ERR-NOT-AUTHORIZED)
    (asserts! (is-eq (get status p) STATUS-PENDING) ERR-INVALID-STATUS)
    (map-set permits { permit-id: permit-id }
      (merge p {
        description: description,
        estimated-value: estimated-value,
        updated-at: (now)
      })
    )
    (ok true)
  )
)

;; -----------------------------
;; Read-Only Views
;; -----------------------------
(define-read-only (get-permit (permit-id uint))
  (map-get? permits { permit-id: permit-id })
)

(define-read-only (get-permit-status (permit-id uint))
  (match (map-get? permits { permit-id: permit-id })
    p (ok (get status p))
    ERR-NOT-FOUND
  )
)

(define-read-only (get-authority (addr principal))
  (map-get? authorities { addr: addr })
)

(define-read-only (get-total-permits)
  (var-get total-permits)
)

(define-read-only (get-applicant-permit-count (applicant principal))
  (match (map-get? applicant-permit-count { applicant: applicant })
    c (ok (get count c))
    (ok u0)
  )
)

(define-read-only (get-permit-id-by-applicant-index (applicant principal) (idx uint))
  (match (map-get? permits-by-applicant { applicant: applicant, idx: idx })
    row (ok (get permit-id row))
    ERR-NOT-FOUND
  )
)

(define-read-only (get-address-permit-count (property-address (string-ascii 200)))
  (match (map-get? address-permit-count { property-address: property-address })
    c (ok (get count c))
    (ok u0)
  )
)

(define-read-only (get-permit-id-by-address-index (property-address (string-ascii 200)) (idx uint))
  (match (map-get? permits-by-address { property-address: property-address, idx: idx })
    row (ok (get permit-id row))
    ERR-NOT-FOUND
  )
)

