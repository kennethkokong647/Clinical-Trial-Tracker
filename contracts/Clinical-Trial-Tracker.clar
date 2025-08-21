(define-fungible-token trial-reward-token)

(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_NOT_AUTHORIZED (err u100))
(define-constant ERR_TRIAL_NOT_FOUND (err u101))
(define-constant ERR_ALREADY_REGISTERED (err u102))
(define-constant ERR_NOT_PARTICIPANT (err u103))
(define-constant ERR_MILESTONE_NOT_FOUND (err u104))
(define-constant ERR_MILESTONE_ALREADY_COMPLETED (err u105))
(define-constant ERR_INSUFFICIENT_FUNDS (err u106))
(define-constant ERR_TRIAL_INACTIVE (err u107))
(define-constant ERR_INVALID_MILESTONE_TYPE (err u108))

(define-data-var next-trial-id uint u1)
(define-data-var token-supply uint u1000000)

(define-map trials
  { trial-id: uint }
  {
    name: (string-ascii 100),
    description: (string-ascii 500),
    researcher: principal,
    total-reward-pool: uint,
    max-participants: uint,
    current-participants: uint,
    start-block: uint,
    end-block: uint,
    active: bool
  })

(define-map participants
  { trial-id: uint, participant: principal }
  {
    registration-block: uint,
    total-rewards-earned: uint,
    milestones-completed: uint,
    active: bool
  })

(define-map milestones
  { trial-id: uint, milestone-id: uint }
  {
    milestone-type: (string-ascii 50),
    reward-amount: uint,
    required-data: (string-ascii 200),
    completion-deadline: uint
  })

(define-map participant-milestones
  { trial-id: uint, participant: principal, milestone-id: uint }
  {
    completed: bool,
    completion-block: uint,
    submitted-data: (string-ascii 500)
  })

(define-map trial-results
  { trial-id: uint }
  {
    results-data: (string-ascii 1000),
    publication-block: uint,
    verified: bool
  })

(define-public (create-trial 
  (name (string-ascii 100))
  (description (string-ascii 500))
  (reward-pool uint)
  (max-participants uint)
  (duration-blocks uint))
  (let
    ((trial-id (var-get next-trial-id)))
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_NOT_AUTHORIZED)
    (try! (ft-mint? trial-reward-token reward-pool tx-sender))
    (map-set trials 
      { trial-id: trial-id }
      {
        name: name,
        description: description,
        researcher: tx-sender,
        total-reward-pool: reward-pool,
        max-participants: max-participants,
        current-participants: u0,
        start-block: stacks-block-height,
        end-block: (+ stacks-block-height duration-blocks),
        active: true
      })
    (var-set next-trial-id (+ trial-id u1))
    (ok trial-id)))

(define-public (register-participant (trial-id uint))
  (let
    ((trial (unwrap! (map-get? trials { trial-id: trial-id }) ERR_TRIAL_NOT_FOUND))
     (existing-participant (map-get? participants { trial-id: trial-id, participant: tx-sender })))
    (asserts! (get active trial) ERR_TRIAL_INACTIVE)
    (asserts! (is-none existing-participant) ERR_ALREADY_REGISTERED)
    (asserts! (< (get current-participants trial) (get max-participants trial)) ERR_INSUFFICIENT_FUNDS)
    (map-set participants 
      { trial-id: trial-id, participant: tx-sender }
      {
        registration-block: stacks-block-height,
        total-rewards-earned: u0,
        milestones-completed: u0,
        active: true
      })
    (map-set trials 
      { trial-id: trial-id }
      (merge trial { current-participants: (+ (get current-participants trial) u1) }))
    (ok true)))

(define-public (add-milestone 
  (trial-id uint)
  (milestone-id uint)
  (milestone-type (string-ascii 50))
  (reward-amount uint)
  (required-data (string-ascii 200))
  (deadline-blocks uint))
  (let
    ((trial (unwrap! (map-get? trials { trial-id: trial-id }) ERR_TRIAL_NOT_FOUND)))
    (asserts! (is-eq tx-sender (get researcher trial)) ERR_NOT_AUTHORIZED)
    (asserts! (get active trial) ERR_TRIAL_INACTIVE)
    (map-set milestones 
      { trial-id: trial-id, milestone-id: milestone-id }
      {
        milestone-type: milestone-type,
        reward-amount: reward-amount,
        required-data: required-data,
        completion-deadline: (+ stacks-block-height deadline-blocks)
      })
    (ok true)))

(define-public (submit-milestone-data 
  (trial-id uint)
  (milestone-id uint)
  (submitted-data (string-ascii 500)))
  (let
    ((trial (unwrap! (map-get? trials { trial-id: trial-id }) ERR_TRIAL_NOT_FOUND))
     (milestone (unwrap! (map-get? milestones { trial-id: trial-id, milestone-id: milestone-id }) ERR_MILESTONE_NOT_FOUND))
     (participant (unwrap! (map-get? participants { trial-id: trial-id, participant: tx-sender }) ERR_NOT_PARTICIPANT))
     (existing-milestone (map-get? participant-milestones { trial-id: trial-id, participant: tx-sender, milestone-id: milestone-id })))
    (asserts! (get active trial) ERR_TRIAL_INACTIVE)
    (asserts! (get active participant) ERR_NOT_PARTICIPANT)
    (asserts! (<= stacks-block-height (get completion-deadline milestone)) ERR_MILESTONE_NOT_FOUND)
    (asserts! (or (is-none existing-milestone) (not (get completed (unwrap-panic existing-milestone)))) ERR_MILESTONE_ALREADY_COMPLETED)
    (map-set participant-milestones 
      { trial-id: trial-id, participant: tx-sender, milestone-id: milestone-id }
      {
        completed: true,
        completion-block: stacks-block-height,
        submitted-data: submitted-data
      })
    (map-set participants 
      { trial-id: trial-id, participant: tx-sender }
      (merge participant { milestones-completed: (+ (get milestones-completed participant) u1) }))
    (try! (ft-transfer? trial-reward-token (get reward-amount milestone) (get researcher trial) tx-sender))
    (map-set participants 
      { trial-id: trial-id, participant: tx-sender }
      (merge participant { total-rewards-earned: (+ (get total-rewards-earned participant) (get reward-amount milestone)) }))
    (ok true)))

(define-public (publish-trial-results 
  (trial-id uint)
  (results-data (string-ascii 1000)))
  (let
    ((trial (unwrap! (map-get? trials { trial-id: trial-id }) ERR_TRIAL_NOT_FOUND)))
    (asserts! (is-eq tx-sender (get researcher trial)) ERR_NOT_AUTHORIZED)
    (map-set trial-results 
      { trial-id: trial-id }
      {
        results-data: results-data,
        publication-block: stacks-block-height,
        verified: false
      })
    (ok true)))

(define-public (verify-trial-results (trial-id uint))
  (let
    ((results (unwrap! (map-get? trial-results { trial-id: trial-id }) ERR_TRIAL_NOT_FOUND)))
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_NOT_AUTHORIZED)
    (map-set trial-results 
      { trial-id: trial-id }
      (merge results { verified: true }))
    (ok true)))

(define-public (deactivate-trial (trial-id uint))
  (let
    ((trial (unwrap! (map-get? trials { trial-id: trial-id }) ERR_TRIAL_NOT_FOUND)))
    (asserts! (is-eq tx-sender (get researcher trial)) ERR_NOT_AUTHORIZED)
    (map-set trials 
      { trial-id: trial-id }
      (merge trial { active: false }))
    (ok true)))

(define-public (emergency-withdraw (trial-id uint) (amount uint))
  (let
    ((trial (unwrap! (map-get? trials { trial-id: trial-id }) ERR_TRIAL_NOT_FOUND)))
    (asserts! (is-eq tx-sender (get researcher trial)) ERR_NOT_AUTHORIZED)
    (asserts! (not (get active trial)) ERR_TRIAL_INACTIVE)
    (try! (ft-transfer? trial-reward-token amount tx-sender CONTRACT_OWNER))
    (ok true)))

(define-read-only (get-trial-info (trial-id uint))
  (map-get? trials { trial-id: trial-id }))

(define-read-only (get-participant-info (trial-id uint) (participant principal))
  (map-get? participants { trial-id: trial-id, participant: participant }))

(define-read-only (get-milestone-info (trial-id uint) (milestone-id uint))
  (map-get? milestones { trial-id: trial-id, milestone-id: milestone-id }))

(define-read-only (get-participant-milestone-status 
  (trial-id uint) 
  (participant principal) 
  (milestone-id uint))
  (map-get? participant-milestones { trial-id: trial-id, participant: participant, milestone-id: milestone-id }))

(define-read-only (get-trial-results (trial-id uint))
  (map-get? trial-results { trial-id: trial-id }))

(define-read-only (get-total-trials)
  (- (var-get next-trial-id) u1))

(define-read-only (get-token-balance (user principal))
  (ft-get-balance trial-reward-token user))

(define-read-only (get-current-block-height)
  stacks-block-height)

(define-read-only (is-trial-active (trial-id uint))
  (match (map-get? trials { trial-id: trial-id })
    trial (and (get active trial) (<= stacks-block-height (get end-block trial)))
    false))

(define-read-only (get-participant-rewards-earned (trial-id uint) (participant principal))
  (match (map-get? participants { trial-id: trial-id, participant: participant })
    participant-data (get total-rewards-earned participant-data)
    u0))

(define-read-only (get-trial-progress (trial-id uint))
  (match (map-get? trials { trial-id: trial-id })
    trial (some {
      current-participants: (get current-participants trial),
      max-participants: (get max-participants trial),
      blocks-remaining: (if (> (get end-block trial) stacks-block-height)
                         (- (get end-block trial) stacks-block-height)
                         u0),
      active: (get active trial)
    })
    none))
