# 🏥 Clinical Trial Tracker

A blockchain-based smart contract platform that revolutionizes clinical trial transparency, participant incentives, and research accountability.

## 🔬 Overview

The Clinical Trial Tracker addresses critical issues in medical research by providing:
- **Transparent** participant registration and milestone tracking
- **Fair token rewards** for participant contributions
- **Immutable** trial progress and results logging
- **Trustworthy** research environment with blockchain accountability

## ✨ Key Features

- 🧑‍🔬 **Researcher Trial Management**: Create and manage clinical trials with customizable parameters
- 👥 **Participant Registration**: Secure on-chain participant enrollment with capacity controls
- 🎯 **Milestone Tracking**: Define and reward completion of specific trial milestones
- 🪙 **Token Rewards**: Automatic token distribution for milestone achievements
- 📊 **Results Publication**: Transparent logging of trial outcomes
- 🔒 **Verification System**: Contract owner verification of published results

## 🚀 Getting Started

### Prerequisites

- Clarinet CLI installed
- Stacks blockchain development environment

### Installation

1. Clone this repository
2. Navigate to project directory
3. Run `clarinet check` to verify contract compilation

## 📋 Usage Guide

### For Researchers

#### Creating a Trial
```clarity
(contract-call? .Clinical-Trial-Tracker create-trial 
  "COVID-19 Vaccine Study"
  "Phase 3 trial testing vaccine efficacy"
  u100000   ; reward pool
  u100      ; max participants  
  u1000)    ; duration in blocks
```

#### Adding Milestones
```clarity
(contract-call? .Clinical-Trial-Tracker add-milestone
  u1        ; trial-id
  u1        ; milestone-id
  "data-submission"
  u1000     ; reward amount
  "Submit daily symptom logs"
  u100)     ; deadline in blocks
```

#### Publishing Results
```clarity
(contract-call? .Clinical-Trial-Tracker publish-trial-results
  u1        ; trial-id
  "Vaccine showed 95% efficacy in preventing infection")
```

### For Participants

#### Registering for a Trial
```clarity
(contract-call? .Clinical-Trial-Tracker register-participant u1)
```

#### Submitting Milestone Data
```clarity
(contract-call? .Clinical-Trial-Tracker submit-milestone-data
  u1        ; trial-id
  u1        ; milestone-id
  "Daily symptoms: none reported, feeling healthy")
```

### Query Functions

#### Get Trial Information
```clarity
(contract-call? .Clinical-Trial-Tracker get-trial-info u1)
```

#### Check Participant Status
```clarity
(contract-call? .Clinical-Trial-Tracker get-participant-info u1 'SP1ABC...)
```

#### View Trial Progress
```clarity
(contract-call? .Clinical-Trial-Tracker get-trial-progress u1)
```

#### Check Token Balance
```clarity
(contract-call? .Clinical-Trial-Tracker get-token-balance 'SP1ABC...)
```

## 🏗️ Contract Architecture

### Data Structures

- **Trials**: Core trial metadata and status
- **Participants**: Registration and reward tracking
- **Milestones**: Task definitions and rewards
- **Participant Milestones**: Individual completion status
- **Trial Results**: Published outcomes and verification

### Token Economics

- Fungible token: `trial-reward-token`
- Automatic minting for trial reward pools
- Direct transfer rewards upon milestone completion
- Emergency withdrawal system for inactive trials

## 🔧 Development

### Testing
```bash
npm install
npm test
```

### Deployment
```bash
clarinet deploy --mainnet
```

## 🛡️ Security Features

- Contract owner authorization for trial creation and verification
- Participant validation and duplicate registration prevention  
- Milestone deadline enforcement
- Active trial status checks
- Emergency withdrawal capabilities

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Run `clarinet check` to ensure compilation
5. Submit a pull request

## 📄 License

This project is open source and available under the MIT License.

---

*Revolutionizing clinical trials through blockchain transparency and fair participant incentives* 🚀
