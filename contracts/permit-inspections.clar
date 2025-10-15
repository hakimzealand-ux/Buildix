;; permit-inspections.clar
;; Buildix - Permit Inspection Management
;; No cross-contract calls, no traits.

;; -----------------------------
;; Constants and Errors
;; -----------------------------
(define-constant ERR-NOT-AUTHORIZED (err u200))
(define-constant ERR-NOT-FOUND (err u201))
(define-constant ERR-ALREADY-EXISTS (err u202))
(define-constant ERR-INVALID-STATE (err u203))
(define-constant ERR-INVALID-PARAM (err u204))

(define-constant RESULT-PASS u1)
(define-constant RESULT-FAIL u2)
(define-constant RESULT-CONDITIONAL u3)

(define-constant TYPE-FOUNDATION u1)
(define-constant TYPE-FRAMING u2)
(define-constant TYPE-ELECTRICAL u3)
(define-constant TYPE-PLUMBING u4)
(define-constant TYPE-HVAC u5)
(define-constant TYPE-FINAL u6)

;; -----------------------------
;; Data Variables
;; -----------------------------
(define-data-var contract-admin principal tx-sender)
(define-data-var next-inspection-id uint u1)
(define-data-var total-inspections uint u0)

;; -----------------------------
;; Data Maps
;; -----------------------------
;; Inspectors registry
(define-map inspectors
  { addr: principal }
  {
    name: (string-ascii 100),
    license: (string-ascii 50),
    active: bool,
    created-at: uint
  }
)

;; Inspections by id
(define-map inspections
  { inspection-id: uint }
  {
    permit-id: uint,
    assigned-inspector: (optional principal),
    inspection-type: uint,
    scheduled-date: uint,
    completion-date: (optional uint),
    result: (optional uint),
    notes: (string-ascii 280),
    photos-hash: (string-ascii 64),
    created-at: uint,
    updated-at: uint
  }
)

;; Secondary index: inspections by permit
(define-map inspections-by-permit
  { permit-id: uint, idx: uint }
  {
    inspection-id: uint
  }
)

(define-map permit-inspection-count
  { permit-id: uint }
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

(define-private (is-inspector (who principal))
  (match (map-get? inspectors { addr: who })
    i (get active i)
    false
  )
)

(define-private (ensure-active-inspector (who principal))
  (if (is-inspector who) true false)
)

(define-private (now)
  stacks-block-height
)

(define-private (index-inspection (permit-id uint) (inspection-id uint))
  (let ((cnt (default-to { count: u0 } (map-get? permit-inspection-count { permit-id: permit-id })))
        (next (+ (get count cnt) u1)))
    (map-set inspections-by-permit { permit-id: permit-id, idx: next } { inspection-id: inspection-id })
    (map-set permit-inspection-count { permit-id: permit-id } { count: next })
    true
  )
)

;; -----------------------------
;; Inspector Management
;; -----------------------------
(define-public (register-inspector (addr principal) (name (string-ascii 100)) (license (string-ascii 50)))
  (begin
    (asserts! (is-admin tx-sender) ERR-NOT-AUTHORIZED)
    (asserts! (> (len name) u0) ERR-INVALID-PARAM)
    (asserts! (> (len license) u0) ERR-INVALID-PARAM)
    (asserts! (is-none (map-get? inspectors { addr: addr })) ERR-ALREADY-EXISTS)
    (map-set inspectors { addr: addr }
      {
        name: name,
        license: license,
        active: true,
        created-at: (now)
      }
    )
    (ok true)
  )
)

(define-public (set-inspector-active (addr principal) (active bool))
  (let ((ins (unwrap! (map-get? inspectors { addr: addr }) ERR-NOT-FOUND)))
    (asserts! (is-admin tx-sender) ERR-NOT-AUTHORIZED)
    (map-set inspectors { addr: addr } (merge ins { active: active }))
    (ok active)
  )
)

;; -----------------------------
;; Inspection Lifecycle
;; -----------------------------
(define-public (schedule-inspection
  (permit-id uint)
  (inspection-type uint)
  (scheduled-date uint)
  (notes (string-ascii 280))
  (photos-hash (string-ascii 64))
)
  (begin
    (asserts! (> scheduled-date (now)) ERR-INVALID-PARAM)
    (asserts! (or (is-eq inspection-type TYPE-FOUNDATION)
                  (or (is-eq inspection-type TYPE-FRAMING)
                      (or (is-eq inspection-type TYPE-ELECTRICAL)
                          (or (is-eq inspection-type TYPE-PLUMBING)
                              (or (is-eq inspection-type TYPE-HVAC)
                                  (is-eq inspection-type TYPE-FINAL)))))) ERR-INVALID-PARAM)
    (let ((iid (var-get next-inspection-id))
          (created (now)))
      (map-set inspections { inspection-id: iid }
        {
          permit-id: permit-id,
          assigned-inspector: none,
          inspection-type: inspection-type,
          scheduled-date: scheduled-date,
          completion-date: none,
          result: none,
          notes: notes,
          photos-hash: photos-hash,
          created-at: created,
          updated-at: created
        }
      )
      (index-inspection permit-id iid)
      (var-set total-inspections (+ (var-get total-inspections) u1))
      (var-set next-inspection-id (+ iid u1))
      (ok iid)
    )
  )
)

(define-public (assign-inspector (inspection-id uint) (inspector principal))
  (let ((insp (unwrap! (map-get? inspections { inspection-id: inspection-id }) ERR-NOT-FOUND)))
(asserts! (ensure-active-inspector inspector) ERR-NOT-AUTHORIZED)
    (asserts! (is-admin tx-sender) ERR-NOT-AUTHORIZED)
    (asserts! (is-none (get completion-date insp)) ERR-INVALID-STATE)
    (map-set inspections { inspection-id: inspection-id }
      (merge insp {
        assigned-inspector: (some inspector),
        updated-at: (now)
      })
    )
    (ok true)
  )
)

(define-public (record-inspection (inspection-id uint) (result uint) (notes (string-ascii 280)) (photos-hash (string-ascii 64)))
  (let ((insp (unwrap! (map-get? inspections { inspection-id: inspection-id }) ERR-NOT-FOUND)))
    (let ((assigned (default-to tx-sender (get assigned-inspector insp))))
(asserts! (ensure-active-inspector assigned) ERR-NOT-AUTHORIZED)
      (asserts! (is-eq tx-sender assigned) ERR-NOT-AUTHORIZED)
      (asserts! (is-none (get completion-date insp)) ERR-INVALID-STATE)
      (asserts! (or (is-eq result RESULT-PASS)
                    (or (is-eq result RESULT-FAIL)
                        (is-eq result RESULT-CONDITIONAL))) ERR-INVALID-PARAM)
      (map-set inspections { inspection-id: inspection-id }
        (merge insp {
          result: (some result),
          completion-date: (some (now)),
          notes: notes,
          photos-hash: photos-hash,
          updated-at: (now)
        })
      )
      (ok true)
    )
  )
)

(define-public (update-notes (inspection-id uint) (notes (string-ascii 280)))
  (let ((insp (unwrap! (map-get? inspections { inspection-id: inspection-id }) ERR-NOT-FOUND)))
    (let ((assigned (default-to tx-sender (get assigned-inspector insp))))
      (asserts! (is-eq tx-sender assigned) ERR-NOT-AUTHORIZED)
      (map-set inspections { inspection-id: inspection-id } (merge insp { notes: notes, updated-at: (now) }))
      (ok true)
    )
  )
)

;; -----------------------------
;; Read-Only Views
;; -----------------------------
(define-read-only (get-inspection (inspection-id uint))
  (map-get? inspections { inspection-id: inspection-id })
)

(define-read-only (get-total-inspections)
  (var-get total-inspections)
)

(define-read-only (get-permit-inspection-count (permit-id uint))
  (match (map-get? permit-inspection-count { permit-id: permit-id })
    c (ok (get count c))
    (ok u0)
  )
)

(define-read-only (get-inspection-id-by-permit-index (permit-id uint) (idx uint))
  (match (map-get? inspections-by-permit { permit-id: permit-id, idx: idx })
    row (ok (get inspection-id row))
    ERR-NOT-FOUND
  )
)

(define-read-only (get-inspector (addr principal))
  (map-get? inspectors { addr: addr })
)

