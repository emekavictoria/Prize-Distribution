# Randomized Prize Distribution Contract

A robust Clarity smart contract for creating and managing randomized prize pools on the Stacks blockchain. This contract enables fair, transparent, and automated prize distribution using cryptographically secure randomness.

## Features

### Core Functionality
- **Prize Pool Creation**: Users can create customizable prize pools with entry fees and participant limits
- **Fair Entry System**: Automated entry fee collection with duplicate prevention
- **Cryptographic Randomness**: Winner selection using blockchain VRF (Verifiable Random Function) seeds
- **Automatic Distribution**: Prize and fee distribution upon winner selection
- **Emergency Controls**: Pool creators and contract owner can close pools if needed

### Security Features
- **Access Control**: Owner-only administrative functions
- **Input Validation**: Comprehensive parameter checking
- **Balance Verification**: Ensures sufficient funds before transfers
- **Error Handling**: 7 distinct error codes for different scenarios

## Contract Structure

### Data Storage
- `prize-pools`: Main pool information (creator, prize amount, participants, status)
- `participants`: Individual participant data with timestamps
- `participant-list`: Indexed participant storage for efficient winner selection

### Key Functions

#### Public Functions
- `create-pool(entry-fee, max-participants)`: Create a new prize pool
- `join-pool(pool-id)`: Join an existing active pool
- `draw-winner(pool-id)`: Select and distribute prize to random winner
- `emergency-close-pool(pool-id)`: Close a pool (creator/owner only)
- `set-fee-rate(new-rate)`: Adjust contract fee rate (owner only)
- `withdraw-fees(amount)`: Withdraw collected fees (owner only)

#### Read-Only Functions
- `get-pool-info(pool-id)`: Retrieve pool details
- `get-participant-info(pool-id, participant)`: Check participation status
- `get-contract-balance()`: View contract STX balance
- `calculate-fees(amount)`: Calculate fee for given amount

## Usage Flow

1. **Pool Creation**: A user creates a pool with specified entry fee and participant limit
2. **Participation**: Users join by paying the entry fee (duplicates prevented)
3. **Prize Accumulation**: Entry fees automatically accumulate in the prize pool
4. **Winner Selection**: Creator or owner triggers random winner selection
5. **Prize Distribution**: Winner receives prize minus contract fee, fees go to owner

## Fee Structure

- Default contract fee: 2.5% (250 basis points)
- Configurable by contract owner (max 10%)
- Fees automatically deducted from prize and sent to contract owner
- Winners receive remaining prize amount

## Randomness Generation

The contract uses multiple entropy sources for secure randomness:
- Blockchain VRF seeds
- Current block height
- Pool ID
- Participant count
- Prime number multipliers for enhanced distribution

## Error Codes

| Code | Description |
|------|-------------|
| u100 | Owner-only function called by non-owner |
| u101 | Pool not found |
| u102 | Insufficient balance |
| u103 | Invalid amount parameter |
| u104 | Pool is closed/inactive |
| u105 | Prize already claimed |
| u106 | Invalid participant (duplicate or none) |
| u107 | Pool is still active |

## Deployment

1. Deploy the contract to Stacks blockchain
2. Contract deployer automatically becomes owner
3. Default fee rate is set to 2.5%
4. Ready to accept pool creation

## Security Considerations

- **Trust Model**: Contract owner has administrative privileges
- **Randomness**: Uses blockchain VRF for cryptographic security
- **Fund Safety**: All transfers are atomic with proper error handling
- **Gas Efficiency**: Optimized for minimal transaction costs

## Example Usage

```clarity
;; Create a pool with 1000 STX entry fee, max 10 participants
(contract-call? .prize-distribution create-pool u1000000 u10)

;; Join pool #1
(contract-call? .prize-distribution join-pool u1)

;; Draw winner for pool #1
(contract-call? .prize-distribution draw-winner u1)
```
