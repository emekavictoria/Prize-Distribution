;; Randomized Prize Distribution Contract
;; A robust contract for managing prize pools and random distribution

;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-found (err u101))
(define-constant err-insufficient-balance (err u102))
(define-constant err-invalid-amount (err u103))
(define-constant err-pool-closed (err u104))
(define-constant err-already-claimed (err u105))
(define-constant err-invalid-participant (err u106))
(define-constant err-pool-active (err u107))

;; Data Variables
(define-data-var pool-counter uint u0)
(define-data-var contract-fee-rate uint u250) ;; 2.5% in basis points

;; Data Maps
(define-map prize-pools 
  { pool-id: uint }
  {
    creator: principal,
    total-prize: uint,
    entry-fee: uint,
    max-participants: uint,
    current-participants: uint,
    is-active: bool,
    winner: (optional principal),
    created-at: uint,
    ended-at: (optional uint)
  }
)

(define-map participants 
  { pool-id: uint, participant: principal }
  { entry-time: uint, claimed: bool }
)

(define-map participant-list
  { pool-id: uint, index: uint }
  { participant: principal }
)

;; Read-only functions
(define-read-only (get-pool-info (pool-id uint))
  (map-get? prize-pools { pool-id: pool-id })
)

(define-read-only (get-participant-info (pool-id uint) (participant principal))
  (map-get? participants { pool-id: pool-id, participant: participant })
)

(define-read-only (get-contract-balance)
  (stx-get-balance (as-contract tx-sender))
)

(define-read-only (get-pool-count)
  (var-get pool-counter)
)

(define-read-only (get-fee-rate)
  (var-get contract-fee-rate)
)

(define-read-only (calculate-fees (amount uint))
  (/ (* amount (var-get contract-fee-rate)) u10000)
)

(define-read-only (get-participant-by-index (pool-id uint) (index uint))
  (map-get? participant-list { pool-id: pool-id, index: index })
)

;; Private functions
(define-private (generate-random-seed (pool-id uint))
  (let ((current-block block-height)
        (pool-data (unwrap-panic (get-pool-info pool-id)))
        (vrf-seed (unwrap-panic (get-block-info? vrf-seed current-block))))
    (+ 
      (mod (len vrf-seed) u1000000)
      (* pool-id u137)
      (* current-block u73)
      (* (get current-participants pool-data) u47)
    )
  )
)

(define-private (select-winner (pool-id uint))
  (let ((pool-data (unwrap-panic (get-pool-info pool-id)))
        (participant-count (get current-participants pool-data))
        (random-seed (generate-random-seed pool-id)))
    (if (> participant-count u0)
      (let ((winner-index (mod random-seed participant-count)))
        (some (get participant (unwrap-panic (get-participant-by-index pool-id winner-index)))))
      none
    )
  )
)

(define-private (distribute-prize (pool-id uint) (winner principal))
  (let ((pool-data (unwrap-panic (get-pool-info pool-id)))
        (prize-amount (get total-prize pool-data))
        (fee-amount (calculate-fees prize-amount))
        (winner-amount (- prize-amount fee-amount)))
    (begin
      (try! (as-contract (stx-transfer? winner-amount tx-sender winner)))
      (try! (as-contract (stx-transfer? fee-amount tx-sender contract-owner)))
      (ok true)
    )
  )
)

;; Public functions
(define-public (create-pool (entry-fee uint) (max-participants uint))
  (let ((pool-id (+ (var-get pool-counter) u1))
        (current-time block-height))
    (asserts! (> entry-fee u0) err-invalid-amount)
    (asserts! (> max-participants u1) err-invalid-amount)
    
    (map-set prize-pools 
      { pool-id: pool-id }
      {
        creator: tx-sender,
        total-prize: u0,
        entry-fee: entry-fee,
        max-participants: max-participants,
        current-participants: u0,
        is-active: true,
        winner: none,
        created-at: current-time,
        ended-at: none
      }
    )
    
    (var-set pool-counter pool-id)
    (ok pool-id)
  )
)

(define-public (join-pool (pool-id uint))
  (let ((pool-data (unwrap! (get-pool-info pool-id) err-not-found))
        (entry-fee (get entry-fee pool-data))
        (current-time block-height))
    
    (asserts! (get is-active pool-data) err-pool-closed)
    (asserts! (< (get current-participants pool-data) (get max-participants pool-data)) err-pool-closed)
    (asserts! (is-none (get-participant-info pool-id tx-sender)) err-invalid-participant)
    
    (try! (stx-transfer? entry-fee tx-sender (as-contract tx-sender)))
    
    (map-set participants 
      { pool-id: pool-id, participant: tx-sender }
      { entry-time: current-time, claimed: false }
    )
    
    (map-set participant-list
      { pool-id: pool-id, index: (get current-participants pool-data) }
      { participant: tx-sender }
    )
    
    (map-set prize-pools
      { pool-id: pool-id }
      (merge pool-data {
        current-participants: (+ (get current-participants pool-data) u1),
        total-prize: (+ (get total-prize pool-data) entry-fee)
      })
    )
    
    (ok true)
  )
)

(define-public (draw-winner (pool-id uint))
  (let ((pool-data (unwrap! (get-pool-info pool-id) err-not-found))
        (winner (select-winner pool-id))
        (current-time block-height))
    
    (asserts! (get is-active pool-data) err-pool-closed)
    (asserts! (or 
      (is-eq tx-sender (get creator pool-data))
      (is-eq tx-sender contract-owner)
      (>= (get current-participants pool-data) (get max-participants pool-data))
    ) err-owner-only)
    (asserts! (> (get current-participants pool-data) u0) err-invalid-participant)
    
    (map-set prize-pools
      { pool-id: pool-id }
      (merge pool-data {
        is-active: false,
        winner: winner,
        ended-at: (some current-time)
      })
    )
    
    (begin
      (match winner
        winning-participant (try! (distribute-prize pool-id winning-participant))
        true
      )
      (ok winner)
    )
  )
)

(define-public (emergency-close-pool (pool-id uint))
  (let ((pool-data (unwrap! (get-pool-info pool-id) err-not-found)))
    (asserts! (or 
      (is-eq tx-sender (get creator pool-data))
      (is-eq tx-sender contract-owner)
    ) err-owner-only)
    (asserts! (get is-active pool-data) err-pool-closed)
    
    (map-set prize-pools
      { pool-id: pool-id }
      (merge pool-data {
        is-active: false,
        ended-at: (some block-height)
      })
    )
    
    (ok true)
  )
)

(define-public (set-fee-rate (new-rate uint))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (asserts! (<= new-rate u1000) err-invalid-amount) ;; Max 10%
    (var-set contract-fee-rate new-rate)
    (ok true)
  )
)

(define-public (withdraw-fees (amount uint))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (asserts! (<= amount (get-contract-balance)) err-insufficient-balance)
    (try! (as-contract (stx-transfer? amount tx-sender contract-owner)))
    (ok true)
  )
)