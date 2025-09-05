;; Simplified Mesa Forge Living NFT Creator Platform
;; Streamlined version with reduced complexity and error potential

;; Error Constants
(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-INVALID-EVOLUTION-PHASE (err u101))
(define-constant ERR-CREATOR-NOT-FOUND (err u102))
(define-constant ERR-INVALID-ENGAGEMENT (err u103))
(define-constant ERR-INVALID-TIER (err u104))
(define-constant ERR-ALREADY-EXISTS (err u105))

;; Data Variables
(define-data-var contract-owner principal tx-sender)
(define-data-var current-evolution-phase uint u1)
(define-data-var total-creators uint u0)
(define-data-var base-mesa-reward uint u100)
(define-data-var platform-active bool true)

;; Constants
(define-constant EVOLUTION-GENESIS u1)
(define-constant EVOLUTION-GROWTH u2)
(define-constant EVOLUTION-MASTERY u3)
(define-constant EVOLUTION-LEGENDARY u4)

(define-constant TIER-BASE u1)
(define-constant TIER-ENGAGEMENT u2)
(define-constant TIER-EVOLUTION u3)

;; Simplified Creator Structure
(define-map creators 
  principal 
  {
    reputation-score: uint,
    total-engagements: uint,
    last-active-phase: uint,
    is-active: bool
  }
)

;; Simplified Engagement Tracking
(define-map engagements
  {creator: principal, phase: uint, engagement-id: uint}
  {
    tier-type: uint,
    impact-rating: uint,
    block-height: uint,
    validated: bool
  }
)

;; Simple Tier Tracking
(define-map tiers
  uint
  {
    tier-type: uint,
    active-nfts: uint,
    total-participation: uint
  }
)

;; Evolution Phase Metrics
(define-map phase-stats
  uint
  {
    total-activity: uint,
    creator-count: uint,
    rewards-distributed: uint
  }
)

;; Simple counter for engagement IDs
(define-data-var next-engagement-id uint u1)

;; Initialize Contract
(define-private (initialize-tiers)
  (begin
    (map-set tiers TIER-BASE {
      tier-type: TIER-BASE,
      active-nfts: u0,
      total-participation: u0
    })
    (map-set tiers TIER-ENGAGEMENT {
      tier-type: TIER-ENGAGEMENT,
      active-nfts: u0,
      total-participation: u0
    })
    (map-set tiers TIER-EVOLUTION {
      tier-type: TIER-EVOLUTION,
      active-nfts: u0,
      total-participation: u0
    })
    (ok true)
  )
)

;; Owner Functions
(define-public (set-base-mesa-reward (new-reward uint))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR-NOT-AUTHORIZED)
    (var-set base-mesa-reward new-reward)
    (ok true)
  )
)

(define-public (advance-evolution-phase)
  (let ((current (var-get current-evolution-phase)))
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR-NOT-AUTHORIZED)
    (var-set current-evolution-phase 
      (if (is-eq current u4) u1 (+ current u1)))
    (ok true)
  )
)

(define-public (set-platform-active (active bool))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR-NOT-AUTHORIZED)
    (var-set platform-active active)
    (ok true)
  )
)

;; Creator Functions
(define-public (register-creator)
  (let ((creator tx-sender))
    (asserts! (var-get platform-active) ERR-NOT-AUTHORIZED)
    (asserts! (is-none (map-get? creators creator)) ERR-ALREADY-EXISTS)
    
    (map-set creators creator {
      reputation-score: u100,
      total-engagements: u0,
      last-active-phase: (var-get current-evolution-phase),
      is-active: true
    })
    (var-set total-creators (+ (var-get total-creators) u1))
    (ok true)
  )
)

(define-public (submit-engagement (tier-type uint) (impact-rating uint))
  (let (
    (creator tx-sender)
    (phase (var-get current-evolution-phase))
    (engagement-id (var-get next-engagement-id))
    (creator-data (unwrap! (map-get? creators creator) ERR-CREATOR-NOT-FOUND))
  )
    (asserts! (var-get platform-active) ERR-NOT-AUTHORIZED)
    (asserts! (and (>= tier-type u1) (<= tier-type u3)) ERR-INVALID-TIER)
    (asserts! (and (>= impact-rating u1) (<= impact-rating u10)) ERR-INVALID-ENGAGEMENT)
    
    ;; Record engagement
    (map-set engagements {creator: creator, phase: phase, engagement-id: engagement-id} {
      tier-type: tier-type,
      impact-rating: impact-rating,
      block-height: block-height,
      validated: false
    })
    
    ;; Update creator data
    (map-set creators creator (merge creator-data {
      total-engagements: (+ (get total-engagements creator-data) u1),
      last-active-phase: phase
    }))
    
    ;; Update tier participation
    (let ((tier-data (unwrap! (map-get? tiers tier-type) ERR-INVALID-TIER)))
      (map-set tiers tier-type (merge tier-data {
        total-participation: (+ (get total-participation tier-data) u1)
      }))
    )
    
    ;; Increment engagement counter
    (var-set next-engagement-id (+ engagement-id u1))
    (ok engagement-id)
  )
)

(define-public (validate-engagement (creator principal) (phase uint) (engagement-id uint))
  (let (
    (validator tx-sender)
    (engagement-key {creator: creator, phase: phase, engagement-id: engagement-id})
    (engagement-data (unwrap! (map-get? engagements engagement-key) ERR-CREATOR-NOT-FOUND))
  )
    (asserts! (var-get platform-active) ERR-NOT-AUTHORIZED)
    (asserts! (is-some (map-get? creators validator)) ERR-CREATOR-NOT-FOUND)
    (asserts! (not (is-eq validator creator)) ERR-NOT-AUTHORIZED) ;; Can't validate own engagement
    
    ;; Mark as validated
    (map-set engagements engagement-key (merge engagement-data {
      validated: true
    }))
    
    ;; Update validator's reputation
    (let ((validator-data (unwrap! (map-get? creators validator) ERR-CREATOR-NOT-FOUND)))
      (map-set creators validator (merge validator-data {
        reputation-score: (+ (get reputation-score validator-data) u5)
      }))
    )
    
    (ok true)
  )
)

(define-public (distribute-phase-rewards)
  (let ((phase (var-get current-evolution-phase)))
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR-NOT-AUTHORIZED)
    
    ;; Update phase stats
    (map-set phase-stats phase {
      total-activity: (get-phase-activity phase),
      creator-count: (var-get total-creators),
      rewards-distributed: (* (var-get base-mesa-reward) (var-get total-creators))
    })
    (ok true)
  )
)

;; Helper Functions
(define-private (get-phase-activity (phase uint))
  ;; Simple activity calculation - returns a placeholder value
  ;; In a real implementation, this would count actual engagements for the phase
  u10
)

;; Read-Only Functions
(define-read-only (get-creator-info (creator principal))
  (map-get? creators creator)
)

(define-read-only (get-engagement (creator principal) (phase uint) (engagement-id uint))
  (map-get? engagements {creator: creator, phase: phase, engagement-id: engagement-id})
)

(define-read-only (get-tier-info (tier-type uint))
  (map-get? tiers tier-type)
)

(define-read-only (get-phase-stats (phase uint))
  (map-get? phase-stats phase)
)

(define-read-only (get-current-evolution-phase)
  (var-get current-evolution-phase)
)

(define-read-only (get-platform-status)
  (var-get platform-active)
)

(define-read-only (get-contract-stats)
  {
    current-evolution-phase: (var-get current-evolution-phase),
    total-creators: (var-get total-creators),
    base-mesa-reward: (var-get base-mesa-reward),
    platform-active: (var-get platform-active),
    next-engagement-id: (var-get next-engagement-id)
  }
)

(define-read-only (get-creator-engagements (creator principal) (phase uint))
  ;; Returns basic info about creator's engagements for a phase
  {
    creator: creator,
    phase: phase,
    total-engagements: (default-to u0 
      (get total-engagements (map-get? creators creator)))
  }
)

;; Initialize contract on deployment
(initialize-tiers)