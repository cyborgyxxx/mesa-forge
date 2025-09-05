;; Simplified Mesa Forge Living NFT Creator Platform
;; Streamlined version with reduced complexity and error potential

;; Error Constants
(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-INVALID-EVOLUTION-PHASE (err u101))
(define-constant ERR-CREATOR-NOT-FOUND (err u102))
(define-constant ERR-INVALID-ENGAGEMENT (err u103))
(define-constant ERR-INVALID-TIER (err u104))
(define-constant ERR-ALREADY-EXISTS (err u105))
(define-constant ERR-PLATFORM-INACTIVE (err u106))

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
    is-active: bool,
    registration-block: uint
  }
)

;; Simplified Engagement Tracking
(define-map engagements
  {creator: principal, phase: uint, engagement-id: uint}
  {
    tier-type: uint,
    impact-rating: uint,
    block-height: uint,
    validated: bool,
    validator: (optional principal)
  }
)

;; Simple Tier Tracking
(define-map tiers
  uint
  {
    tier-type: uint,
    active-nfts: uint,
    total-participation: uint,
    last-updated: uint
  }
)

;; Evolution Phase Metrics
(define-map phase-stats
  uint
  {
    total-activity: uint,
    creator-count: uint,
    rewards-distributed: uint,
    last-epoch-block: uint
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
      total-participation: u0,
      last-updated: block-height
    })
    (map-set tiers TIER-ENGAGEMENT {
      tier-type: TIER-ENGAGEMENT,
      active-nfts: u0,
      total-participation: u0,
      last-updated: block-height
    })
    (map-set tiers TIER-EVOLUTION {
      tier-type: TIER-EVOLUTION,
      active-nfts: u0,
      total-participation: u0,
      last-updated: block-height
    })
    
    ;; Initialize phase stats for all phases
    (map-set phase-stats EVOLUTION-GENESIS {
      total-activity: u0,
      creator-count: u0,
      rewards-distributed: u0,
      last-epoch-block: block-height
    })
    (map-set phase-stats EVOLUTION-GROWTH {
      total-activity: u0,
      creator-count: u0,
      rewards-distributed: u0,
      last-epoch-block: block-height
    })
    (map-set phase-stats EVOLUTION-MASTERY {
      total-activity: u0,
      creator-count: u0,
      rewards-distributed: u0,
      last-epoch-block: block-height
    })
    (map-set phase-stats EVOLUTION-LEGENDARY {
      total-activity: u0,
      creator-count: u0,
      rewards-distributed: u0,
      last-epoch-block: block-height
    })
    (ok true)
  )
)

;; Owner Functions
(define-public (set-base-mesa-reward (new-reward uint))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR-NOT-AUTHORIZED)
    (asserts! (> new-reward u0) ERR-INVALID-ENGAGEMENT)
    (var-set base-mesa-reward new-reward)
    (ok true)
  )
)

(define-public (advance-evolution-phase)
  (let ((current (var-get current-evolution-phase)))
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR-NOT-AUTHORIZED)
    (var-set current-evolution-phase 
      (if (is-eq current EVOLUTION-LEGENDARY) EVOLUTION-GENESIS (+ current u1)))
    (ok (var-get current-evolution-phase))
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
    (asserts! (var-get platform-active) ERR-PLATFORM-INACTIVE)
    (asserts! (is-none (map-get? creators creator)) ERR-ALREADY-EXISTS)
    
    (map-set creators creator {
      reputation-score: u100,
      total-engagements: u0,
      last-active-phase: (var-get current-evolution-phase),
      is-active: true,
      registration-block: block-height
    })
    (var-set total-creators (+ (var-get total-creators) u1))
    (ok true)
  )
)

(define-public (deactivate-creator)
  (let (
    (creator tx-sender)
    (creator-data (unwrap! (map-get? creators creator) ERR-CREATOR-NOT-FOUND))
  )
    (asserts! (var-get platform-active) ERR-PLATFORM-INACTIVE)
    (asserts! (get is-active creator-data) ERR-CREATOR-NOT-FOUND)
    
    (map-set creators creator (merge creator-data {
      is-active: false
    }))
    (var-set total-creators (- (var-get total-creators) u1))
    (ok true)
  )
)

(define-public (reactivate-creator)
  (let (
    (creator tx-sender)
    (creator-data (unwrap! (map-get? creators creator) ERR-CREATOR-NOT-FOUND))
  )
    (asserts! (var-get platform-active) ERR-PLATFORM-INACTIVE)
    (asserts! (not (get is-active creator-data)) ERR-ALREADY-EXISTS)
    
    (map-set creators creator (merge creator-data {
      is-active: true,
      last-active-phase: (var-get current-evolution-phase)
    }))
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
    (asserts! (var-get platform-active) ERR-PLATFORM-INACTIVE)
    (asserts! (get is-active creator-data) ERR-CREATOR-NOT-FOUND)
    (asserts! (is-valid-tier-type tier-type) ERR-INVALID-TIER)
    (asserts! (is-valid-impact-rating impact-rating) ERR-INVALID-ENGAGEMENT)
    
    ;; Record engagement
    (map-set engagements {creator: creator, phase: phase, engagement-id: engagement-id} {
      tier-type: tier-type,
      impact-rating: impact-rating,
      block-height: block-height,
      validated: false,
      validator: none
    })
    
    ;; Update creator data
    (map-set creators creator (merge creator-data {
      total-engagements: (+ (get total-engagements creator-data) u1),
      last-active-phase: phase
    }))
    
    ;; Update tier participation safely
    (update-tier-participation-safe tier-type)
    
    ;; Update phase activity safely
    (update-phase-activity-safe phase)
    
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
    (validator-data (unwrap! (map-get? creators validator) ERR-CREATOR-NOT-FOUND))
  )
    (asserts! (var-get platform-active) ERR-PLATFORM-INACTIVE)
    (asserts! (get is-active validator-data) ERR-CREATOR-NOT-FOUND)
    (asserts! (not (is-eq validator creator)) ERR-NOT-AUTHORIZED) ;; Can't validate own engagement
    (asserts! (not (get validated engagement-data)) ERR-ALREADY-EXISTS) ;; Already validated
    
    ;; Mark as validated
    (map-set engagements engagement-key (merge engagement-data {
      validated: true,
      validator: (some validator)
    }))
    
    ;; Update validator's reputation
    (map-set creators validator (merge validator-data {
      reputation-score: (+ (get reputation-score validator-data) u5),
      last-active-phase: phase
    }))
    
    ;; Update creator's reputation (the one being validated)
    (let ((creator-data-result (map-get? creators creator)))
      (match creator-data-result
        some-creator-data (map-set creators creator (merge some-creator-data {
          reputation-score: (+ (get reputation-score some-creator-data) u3)
        }))
        false))
    
    (ok true)
  )
)

(define-public (claim-engagement-reward (phase uint) (engagement-id uint))
  (let (
    (creator tx-sender)
    (engagement-key {creator: creator, phase: phase, engagement-id: engagement-id})
    (engagement-data (unwrap! (map-get? engagements engagement-key) ERR-CREATOR-NOT-FOUND))
  )
    (asserts! (var-get platform-active) ERR-PLATFORM-INACTIVE)
    (asserts! (get validated engagement-data) ERR-INVALID-ENGAGEMENT)
    
    ;; Calculate reward based on tier and impact
    (let ((reward (calculate-engagement-reward (get tier-type engagement-data) (get impact-rating engagement-data))))
      (ok reward)
    )
  )
)

(define-public (distribute-phase-rewards)
  (let ((phase (var-get current-evolution-phase)))
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR-NOT-AUTHORIZED)
    
    (let ((total-reward (* (var-get base-mesa-reward) (var-get total-creators))))
      ;; Update phase stats safely
      (let ((phase-data-result (map-get? phase-stats phase)))
        (match phase-data-result
          some-phase-data (begin
            (map-set phase-stats phase (merge some-phase-data {
              total-activity: (get-phase-activity phase),
              creator-count: (var-get total-creators),
              rewards-distributed: (+ (get rewards-distributed some-phase-data) total-reward),
              last-epoch-block: block-height
            }))
            (ok total-reward))
          (ok total-reward)))
    )
  )
)

;; Helper Functions
(define-private (is-valid-tier-type (tier-type uint))
  (and (>= tier-type TIER-BASE) (<= tier-type TIER-EVOLUTION))
)

(define-private (is-valid-impact-rating (rating uint))
  (and (>= rating u1) (<= rating u10))
)

(define-private (calculate-engagement-reward (tier-type uint) (impact-rating uint))
  (let ((base (var-get base-mesa-reward)))
    (* base 
       (get-tier-multiplier tier-type)
       impact-rating)
  )
)

(define-private (get-tier-multiplier (tier-type uint))
  (if (is-eq tier-type TIER-BASE) u1
    (if (is-eq tier-type TIER-ENGAGEMENT) u2
      u3))) ;; TIER-EVOLUTION

(define-private (get-phase-activity (phase uint))
  ;; Simple activity calculation - in real implementation would count actual engagements
  (default-to u0 
    (get total-activity (map-get? phase-stats phase)))
)

;; Safe update functions to prevent type mismatches
(define-private (update-tier-participation-safe (tier-type uint))
  (let ((tier-data-result (map-get? tiers tier-type)))
    (match tier-data-result
      some-tier-data (begin
        (map-set tiers tier-type (merge some-tier-data {
          total-participation: (+ (get total-participation some-tier-data) u1),
          last-updated: block-height
        }))
        true)
      false))
)

(define-private (update-phase-activity-safe (phase uint))
  (let ((phase-data-result (map-get? phase-stats phase)))
    (match phase-data-result
      some-phase-data (begin
        (map-set phase-stats phase (merge some-phase-data {
          total-activity: (+ (get total-activity some-phase-data) u1)
        }))
        true)
      false))
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

(define-read-only (get-creator-reputation (creator principal))
  (default-to u0 
    (get reputation-score (map-get? creators creator)))
)

(define-read-only (calculate-creator-efficiency (creator principal))
  (let ((creator-data (map-get? creators creator)))
    (match creator-data
      some-data (let ((total-engagements (get total-engagements some-data)))
        (if (> total-engagements u0)
          ;; Simple efficiency calculation - reputation per engagement
          (/ (get reputation-score some-data) total-engagements)
          u100))
      u0))
)


;; Initialize contract on deployment
(initialize-tiers)