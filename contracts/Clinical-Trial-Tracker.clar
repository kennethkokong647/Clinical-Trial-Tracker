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
(define-constant ERR_INVALID_REPUTATION_SCORE (err u109))
(define-constant ERR_CONSENT_EXPIRED (err u110))
(define-constant ERR_CONSENT_NOT_FOUND (err u111))
(define-constant ERR_DATA_ACCESS_DENIED (err u112))
(define-constant ERR_INVALID_CONSENT_TYPE (err u113))
(define-constant ERR_PROPOSAL_NOT_FOUND (err u114))
(define-constant ERR_ALREADY_VOTED (err u115))
(define-constant ERR_PROPOSAL_EXPIRED (err u116))
(define-constant ERR_PROPOSAL_ALREADY_EXECUTED (err u117))
(define-constant ERR_INSUFFICIENT_APPROVALS (err u118))
(define-constant ERR_NOT_VALIDATOR (err u119))

(define-data-var next-trial-id uint u1)
(define-data-var token-supply uint u1000000)
(define-data-var reputation-multiplier uint u10)
(define-data-var next-consent-id uint u1)
(define-data-var next-proposal-id uint u1)
(define-data-var required-approvals uint u3)

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

(define-map participant-reputation
  { participant: principal }
  {
    total-score: uint,
    trials-completed: uint,
    milestones-completed: uint,
    on-time-completions: uint,
    last-updated-block: uint
  })

(define-map researcher-reputation
  { researcher: principal }
  {
    total-score: uint,
    trials-conducted: uint,
    successful-trials: uint,
    participant-satisfaction: uint,
    last-updated-block: uint
  })

(define-map data-consent
  { consent-id: uint }
  {
    participant: principal,
    trial-id: uint,
    consent-type: (string-ascii 50),
    data-categories: (string-ascii 200),
    authorized-parties: (list 5 principal),
    expiry-block: uint,
    revokable: bool,
    active: bool,
    granted-block: uint
  })

(define-map participant-consent-registry
  { participant: principal, trial-id: uint }
  {
    consent-ids: (list 10 uint),
    total-consents: uint,
    last-updated: uint
  })

(define-map data-access-log
  { trial-id: uint, participant: principal, accessor: principal }
  {
    access-count: uint,
    last-access-block: uint,
    data-types-accessed: (string-ascii 300),
    consent-id-used: uint
  })

(define-map validators
  { validator: principal }
  {
    active: bool,
    proposals-voted: uint,
    added-at-block: uint
  })

(define-map proposals
  { proposal-id: uint }
  {
    proposal-type: (string-ascii 50),
    trial-id: uint,
    proposer: principal,
    target-data: (string-ascii 500),
    approvals: uint,
    rejections: uint,
    executed: bool,
    expiry-block: uint,
    created-at-block: uint
  })

(define-map proposal-votes
  { proposal-id: uint, validator: principal }
  {
    vote: bool,
    voted-at-block: uint
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
    (map-set participant-consent-registry
      { participant: tx-sender, trial-id: trial-id }
      {
        consent-ids: (list),
        total-consents: u0,
        last-updated: stacks-block-height
      })
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
    (unwrap-panic (update-participant-reputation tx-sender true (<= stacks-block-height (get completion-deadline milestone))))
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
    ((results (unwrap! (map-get? trial-results { trial-id: trial-id }) ERR_TRIAL_NOT_FOUND))
     (trial (unwrap! (map-get? trials { trial-id: trial-id }) ERR_TRIAL_NOT_FOUND)))
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_NOT_AUTHORIZED)
    (map-set trial-results 
      { trial-id: trial-id }
      (merge results { verified: true }))
    (unwrap-panic (update-researcher-reputation (get researcher trial) true true))
    (ok true)))

(define-public (deactivate-trial (trial-id uint))
  (let
    ((trial (unwrap! (map-get? trials { trial-id: trial-id }) ERR_TRIAL_NOT_FOUND)))
    (asserts! (is-eq tx-sender (get researcher trial)) ERR_NOT_AUTHORIZED)
    (map-set trials 
      { trial-id: trial-id }
      (merge trial { active: false }))
    (unwrap-panic (update-researcher-reputation (get researcher trial) true false))
    (ok true)))

(define-public (emergency-withdraw (trial-id uint) (amount uint))
  (let
    ((trial (unwrap! (map-get? trials { trial-id: trial-id }) ERR_TRIAL_NOT_FOUND)))
    (asserts! (is-eq tx-sender (get researcher trial)) ERR_NOT_AUTHORIZED)
    (asserts! (not (get active trial)) ERR_TRIAL_INACTIVE)
    (try! (ft-transfer? trial-reward-token amount tx-sender CONTRACT_OWNER))
    (ok true)))

(define-public (grant-data-consent
  (trial-id uint)
  (consent-type (string-ascii 50))
  (data-categories (string-ascii 200))
  (authorized-parties (list 5 principal))
  (duration-blocks uint)
  (revokable bool))
  (let
    ((consent-id (var-get next-consent-id))
     (participant-info (unwrap! (map-get? participants { trial-id: trial-id, participant: tx-sender }) ERR_NOT_PARTICIPANT))
     (registry (default-to 
       { consent-ids: (list), total-consents: u0, last-updated: u0 }
       (map-get? participant-consent-registry { participant: tx-sender, trial-id: trial-id }))))
    (asserts! (get active participant-info) ERR_NOT_PARTICIPANT)
    (asserts! (or (is-eq consent-type "medical-data") 
                  (is-eq consent-type "research-data") 
                  (is-eq consent-type "anonymized-data")
                  (is-eq consent-type "full-data")) ERR_INVALID_CONSENT_TYPE)
    (map-set data-consent
      { consent-id: consent-id }
      {
        participant: tx-sender,
        trial-id: trial-id,
        consent-type: consent-type,
        data-categories: data-categories,
        authorized-parties: authorized-parties,
        expiry-block: (+ stacks-block-height duration-blocks),
        revokable: revokable,
        active: true,
        granted-block: stacks-block-height
      })
    (map-set participant-consent-registry
      { participant: tx-sender, trial-id: trial-id }
      {
        consent-ids: (unwrap-panic (as-max-len? (append (get consent-ids registry) consent-id) u10)),
        total-consents: (+ (get total-consents registry) u1),
        last-updated: stacks-block-height
      })
    (var-set next-consent-id (+ consent-id u1))
    (ok consent-id)))

(define-public (revoke-data-consent (consent-id uint))
  (let
    ((consent (unwrap! (map-get? data-consent { consent-id: consent-id }) ERR_CONSENT_NOT_FOUND)))
    (asserts! (is-eq tx-sender (get participant consent)) ERR_NOT_AUTHORIZED)
    (asserts! (get revokable consent) ERR_NOT_AUTHORIZED)
    (asserts! (get active consent) ERR_CONSENT_NOT_FOUND)
    (map-set data-consent
      { consent-id: consent-id }
      (merge consent { active: false }))
    (ok true)))

(define-public (access-participant-data
  (trial-id uint)
  (participant principal)
  (data-types (string-ascii 300))
  (consent-id uint))
  (let
    ((trial (unwrap! (map-get? trials { trial-id: trial-id }) ERR_TRIAL_NOT_FOUND))
     (consent (unwrap! (map-get? data-consent { consent-id: consent-id }) ERR_CONSENT_NOT_FOUND))
     (access-log (default-to
       { access-count: u0, last-access-block: u0, data-types-accessed: "", consent-id-used: u0 }
       (map-get? data-access-log { trial-id: trial-id, participant: participant, accessor: tx-sender }))))
    (asserts! (get active consent) ERR_CONSENT_EXPIRED)
    (asserts! (<= stacks-block-height (get expiry-block consent)) ERR_CONSENT_EXPIRED)
    (asserts! (is-eq (get participant consent) participant) ERR_DATA_ACCESS_DENIED)
    (asserts! (is-eq (get trial-id consent) trial-id) ERR_DATA_ACCESS_DENIED)
    (asserts! (is-some (index-of (get authorized-parties consent) tx-sender)) ERR_DATA_ACCESS_DENIED)
    (map-set data-access-log
      { trial-id: trial-id, participant: participant, accessor: tx-sender }
      {
        access-count: (+ (get access-count access-log) u1),
        last-access-block: stacks-block-height,
        data-types-accessed: data-types,
        consent-id-used: consent-id
      })
    (ok true)))

(define-public (update-consent-expiry (consent-id uint) (new-expiry-blocks uint))
  (let
    ((consent (unwrap! (map-get? data-consent { consent-id: consent-id }) ERR_CONSENT_NOT_FOUND)))
    (asserts! (is-eq tx-sender (get participant consent)) ERR_NOT_AUTHORIZED)
    (asserts! (get active consent) ERR_CONSENT_NOT_FOUND)
    (map-set data-consent
      { consent-id: consent-id }
      (merge consent { expiry-block: (+ stacks-block-height new-expiry-blocks) }))
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

(define-private (update-participant-reputation (participant principal) (milestone-completed bool) (on-time bool))
  (let
    ((current-rep (default-to 
      { total-score: u100, trials-completed: u0, milestones-completed: u0, on-time-completions: u0, last-updated-block: u0 }
      (map-get? participant-reputation { participant: participant })))
     (score-bonus (if milestone-completed (if on-time u15 u10) u0))
     (new-milestones (if milestone-completed (+ (get milestones-completed current-rep) u1) (get milestones-completed current-rep)))
     (new-on-time (if (and milestone-completed on-time) (+ (get on-time-completions current-rep) u1) (get on-time-completions current-rep))))
    (map-set participant-reputation
      { participant: participant }
      {
        total-score: (+ (get total-score current-rep) score-bonus),
        trials-completed: (get trials-completed current-rep),
        milestones-completed: new-milestones,
        on-time-completions: new-on-time,
        last-updated-block: stacks-block-height
      })
    (ok true)))

(define-private (update-researcher-reputation (researcher principal) (trial-completed bool) (successful bool))
  (let
    ((current-rep (default-to 
      { total-score: u100, trials-conducted: u0, successful-trials: u0, participant-satisfaction: u0, last-updated-block: u0 }
      (map-get? researcher-reputation { researcher: researcher })))
     (score-bonus (if trial-completed (if successful u25 u5) u0))
     (new-trials (if trial-completed (+ (get trials-conducted current-rep) u1) (get trials-conducted current-rep)))
     (new-successful (if (and trial-completed successful) (+ (get successful-trials current-rep) u1) (get successful-trials current-rep))))
    (map-set researcher-reputation
      { researcher: researcher }
      {
        total-score: (+ (get total-score current-rep) score-bonus),
        trials-conducted: new-trials,
        successful-trials: new-successful,
        participant-satisfaction: (get participant-satisfaction current-rep),
        last-updated-block: stacks-block-height
      })
    (ok true)))

(define-public (rate-researcher (trial-id uint) (rating uint))
  (let
    ((trial (unwrap! (map-get? trials { trial-id: trial-id }) ERR_TRIAL_NOT_FOUND))
     (participant-info (unwrap! (map-get? participants { trial-id: trial-id, participant: tx-sender }) ERR_NOT_PARTICIPANT))
     (researcher (get researcher trial))
     (current-rep (default-to 
       { total-score: u100, trials-conducted: u0, successful-trials: u0, participant-satisfaction: u0, last-updated-block: u0 }
       (map-get? researcher-reputation { researcher: researcher }))))
    (asserts! (and (>= rating u1) (<= rating u5)) ERR_INVALID_REPUTATION_SCORE)
    (asserts! (get active participant-info) ERR_NOT_PARTICIPANT)
    (map-set researcher-reputation
      { researcher: researcher }
      (merge current-rep { 
        participant-satisfaction: (+ (get participant-satisfaction current-rep) rating),
        last-updated-block: stacks-block-height 
      }))
    (ok true)))

(define-read-only (get-participant-reputation (participant principal))
  (default-to 
    { total-score: u100, trials-completed: u0, milestones-completed: u0, on-time-completions: u0, last-updated-block: u0 }
    (map-get? participant-reputation { participant: participant })))

(define-read-only (get-researcher-reputation (researcher principal))
  (default-to 
    { total-score: u100, trials-conducted: u0, successful-trials: u0, participant-satisfaction: u0, last-updated-block: u0 }
    (map-get? researcher-reputation { researcher: researcher })))

(define-read-only (get-participant-reliability-score (participant principal))
  (let
    ((rep (get-participant-reputation participant))
     (milestone-count (get milestones-completed rep))
     (on-time (get on-time-completions rep)))
    (if (is-eq milestone-count u0)
        u100
        (/ (* on-time u100) milestone-count))))

(define-read-only (get-researcher-success-rate (researcher principal))
  (let
    ((rep (get-researcher-reputation researcher))
     (conducted (get trials-conducted rep))
     (successful (get successful-trials rep)))
    (if (is-eq conducted u0)
        u100
        (/ (* successful u100) conducted))))

(define-read-only (get-reputation-tier (score uint))
  (if (>= score u200)
      "platinum"
      (if (>= score u150)
          "gold"
          (if (>= score u100)
              "silver"
              "bronze"))))

(define-read-only (get-consent-info (consent-id uint))
  (map-get? data-consent { consent-id: consent-id }))

(define-read-only (get-participant-consents (participant principal) (trial-id uint))
  (map-get? participant-consent-registry { participant: participant, trial-id: trial-id }))

(define-read-only (get-data-access-history (trial-id uint) (participant principal) (accessor principal))
  (map-get? data-access-log { trial-id: trial-id, participant: participant, accessor: accessor }))

(define-read-only (is-consent-valid (consent-id uint))
  (match (map-get? data-consent { consent-id: consent-id })
    consent (and (get active consent) (<= stacks-block-height (get expiry-block consent)))
    false))

(define-read-only (can-access-data (trial-id uint) (participant principal) (accessor principal) (consent-id uint))
  (match (map-get? data-consent { consent-id: consent-id })
    consent (and 
      (get active consent)
      (<= stacks-block-height (get expiry-block consent))
      (is-eq (get participant consent) participant)
      (is-eq (get trial-id consent) trial-id)
      (is-some (index-of (get authorized-parties consent) accessor)))
    false))

(define-public (add-validator (validator principal))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_NOT_AUTHORIZED)
    (map-set validators
      { validator: validator }
      {
        active: true,
        proposals-voted: u0,
        added-at-block: stacks-block-height
      })
    (ok true)))

(define-public (remove-validator (validator principal))
  (let
    ((validator-info (unwrap! (map-get? validators { validator: validator }) ERR_NOT_VALIDATOR)))
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_NOT_AUTHORIZED)
    (map-set validators
      { validator: validator }
      (merge validator-info { active: false }))
    (ok true)))

(define-public (create-proposal
  (proposal-type (string-ascii 50))
  (trial-id uint)
  (target-data (string-ascii 500))
  (duration-blocks uint))
  (let
    ((proposal-id (var-get next-proposal-id))
     (trial (unwrap! (map-get? trials { trial-id: trial-id }) ERR_TRIAL_NOT_FOUND)))
    (asserts! (is-eq tx-sender (get researcher trial)) ERR_NOT_AUTHORIZED)
    (map-set proposals
      { proposal-id: proposal-id }
      {
        proposal-type: proposal-type,
        trial-id: trial-id,
        proposer: tx-sender,
        target-data: target-data,
        approvals: u0,
        rejections: u0,
        executed: false,
        expiry-block: (+ stacks-block-height duration-blocks),
        created-at-block: stacks-block-height
      })
    (var-set next-proposal-id (+ proposal-id u1))
    (ok proposal-id)))

(define-public (vote-on-proposal (proposal-id uint) (approve bool))
  (let
    ((proposal (unwrap! (map-get? proposals { proposal-id: proposal-id }) ERR_PROPOSAL_NOT_FOUND))
     (validator-info (unwrap! (map-get? validators { validator: tx-sender }) ERR_NOT_VALIDATOR))
     (existing-vote (map-get? proposal-votes { proposal-id: proposal-id, validator: tx-sender })))
    (asserts! (get active validator-info) ERR_NOT_VALIDATOR)
    (asserts! (is-none existing-vote) ERR_ALREADY_VOTED)
    (asserts! (<= stacks-block-height (get expiry-block proposal)) ERR_PROPOSAL_EXPIRED)
    (asserts! (not (get executed proposal)) ERR_PROPOSAL_ALREADY_EXECUTED)
    (map-set proposal-votes
      { proposal-id: proposal-id, validator: tx-sender }
      {
        vote: approve,
        voted-at-block: stacks-block-height
      })
    (map-set proposals
      { proposal-id: proposal-id }
      (merge proposal {
        approvals: (if approve (+ (get approvals proposal) u1) (get approvals proposal)),
        rejections: (if approve (get rejections proposal) (+ (get rejections proposal) u1))
      }))
    (map-set validators
      { validator: tx-sender }
      (merge validator-info { proposals-voted: (+ (get proposals-voted validator-info) u1) }))
    (ok true)))

(define-public (execute-proposal (proposal-id uint))
  (let
    ((proposal (unwrap! (map-get? proposals { proposal-id: proposal-id }) ERR_PROPOSAL_NOT_FOUND)))
    (asserts! (is-eq tx-sender (get proposer proposal)) ERR_NOT_AUTHORIZED)
    (asserts! (>= (get approvals proposal) (var-get required-approvals)) ERR_INSUFFICIENT_APPROVALS)
    (asserts! (not (get executed proposal)) ERR_PROPOSAL_ALREADY_EXECUTED)
    (asserts! (<= stacks-block-height (get expiry-block proposal)) ERR_PROPOSAL_EXPIRED)
    (map-set proposals
      { proposal-id: proposal-id }
      (merge proposal { executed: true }))
    (ok true)))

(define-public (update-required-approvals (new-threshold uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_NOT_AUTHORIZED)
    (var-set required-approvals new-threshold)
    (ok true)))

(define-read-only (get-validator-info (validator principal))
  (map-get? validators { validator: validator }))

(define-read-only (is-active-validator (validator principal))
  (match (map-get? validators { validator: validator })
    validator-info (get active validator-info)
    false))

(define-read-only (get-proposal-info (proposal-id uint))
  (map-get? proposals { proposal-id: proposal-id }))

(define-read-only (get-proposal-vote (proposal-id uint) (validator principal))
  (map-get? proposal-votes { proposal-id: proposal-id, validator: validator }))

(define-read-only (get-proposal-status (proposal-id uint))
  (match (map-get? proposals { proposal-id: proposal-id })
    proposal (some {
      approvals: (get approvals proposal),
      rejections: (get rejections proposal),
      required-approvals: (var-get required-approvals),
      can-execute: (and 
        (>= (get approvals proposal) (var-get required-approvals))
        (not (get executed proposal))
        (<= stacks-block-height (get expiry-block proposal))),
      executed: (get executed proposal),
      expired: (> stacks-block-height (get expiry-block proposal))
    })
    none))

(define-read-only (get-total-proposals)
  (- (var-get next-proposal-id) u1))

(define-read-only (get-required-approvals)
  (var-get required-approvals))
