# Buildix - Blockchain Building Permit Registry 🗂️

## Overview

Buildix is a decentralized building permit registry system that provides transparent, immutable verification of legal construction approvals. The system ensures accountability and public access to critical building permit information, reducing fraud and improving compliance tracking.

## Features

### Core Functionality
- **Immutable Permit Storage**: Store building permits permanently on blockchain
- **Public Transparency**: All permits are publicly accessible and verifiable
- **Inspection Tracking**: Complete inspection history for each permit
- **Authority Management**: Role-based permissions for building authorities
- **Verification System**: Cryptographic verification of permit authenticity
- **Audit Trail**: Complete history of all permit-related actions

### Smart Contracts

#### 1. Permit Registry (`permit-registry.clar`)
The main contract that handles:
- Building permit creation and storage
- Permit status management (pending, approved, denied, expired)
- Authority verification and permissions
- Permit lookup and verification functions
- Public access to permit information

#### 2. Permit Inspections (`permit-inspections.clar`)
Manages the inspection ecosystem:
- Inspection scheduling and recording
- Inspector assignment and verification
- Inspection results and compliance tracking
- Final approval processing
- Certificate of occupancy issuance

## Data Structures

**Building Permit**:
- `permit-id`: Unique permit identifier
- `property-address`: Location of construction project
- `permit-type`: Type of construction (residential, commercial, etc.)
- `applicant`: Principal address of permit applicant
- `authority-id`: ID of issuing building authority
- `issue-date`: Block height when permit was issued
- `expiry-date`: Block height when permit expires
- `status`: Current permit status
- `description`: Project description
- `estimated-value`: Estimated construction value

**Inspection Record**:
- `inspection-id`: Unique inspection identifier
- `permit-id`: Associated building permit
- `inspector`: Principal address of inspector
- `inspection-type`: Type of inspection (foundation, framing, final, etc.)
- `scheduled-date`: Planned inspection date
- `completion-date`: Actual inspection date
- `result`: Pass/fail/conditional approval
- `notes`: Inspector notes and comments
- `photos-hash`: Hash of inspection photos

## Usage

### For Property Developers
1. Submit building permit applications
2. Track permit approval status
3. Schedule required inspections
4. Receive digital certificates upon completion
5. Maintain permanent construction records

### For Building Authorities
1. Review and approve/deny permit applications
2. Assign qualified inspectors to projects
3. Track compliance across all active permits
4. Issue certificates of occupancy
5. Maintain transparent public records

### For Citizens
1. Verify building permits for any property
2. Check inspection history and compliance status
3. Access public construction project information
4. Report potential permit violations
5. Track neighborhood development activities

### For Inspectors
1. Receive inspection assignments
2. Record inspection results and observations
3. Upload supporting documentation
4. Coordinate with permit authorities
5. Maintain professional inspection records

## Security Features

- **Immutable Storage**: Permits cannot be altered once issued
- **Cryptographic Integrity**: Document hashes prevent tampering
- **Role-Based Access**: Only authorized entities can issue permits
- **Public Verification**: Anyone can verify permit authenticity
- **Audit Logging**: Complete history of all system interactions
- **Authority Controls**: Multi-signature approvals for sensitive operations

## Permit Types

### Residential Permits
- Single-family home construction
- Home renovations and additions
- Garage and outbuilding construction
- Pool and landscaping projects

### Commercial Permits
- Office building construction
- Retail and restaurant build-outs
- Warehouse and industrial facilities
- Multi-family residential complexes

### Specialized Permits
- Electrical system installations
- Plumbing and HVAC work
- Structural modifications
- Historic building renovations

## Contract Architecture

### Permit Registry Functions

#### Public Functions
- `submit-permit-application`: Apply for new building permit
- `approve-permit`: Authority approves permit application
- `deny-permit`: Authority denies permit with reason
- `renew-permit`: Extend permit expiration date
- `revoke-permit`: Revoke permit for violations

#### Read-Only Functions
- `get-permit-details`: Retrieve complete permit information
- `get-permits-by-address`: Find all permits for property
- `get-permits-by-applicant`: Find all permits by applicant
- `verify-permit-status`: Check current permit status
- `get-authority-info`: Get building authority details

### Inspection Functions

#### Public Functions
- `schedule-inspection`: Request inspection appointment
- `record-inspection`: Inspector records results
- `approve-final-inspection`: Issue certificate of occupancy
- `flag-violation`: Report permit violations
- `assign-inspector`: Authority assigns qualified inspector

#### Read-Only Functions
- `get-inspection-history`: Complete inspection record
- `get-pending-inspections`: List of scheduled inspections
- `get-inspector-schedule`: Inspector's assigned inspections
- `verify-completion`: Check project completion status
- `get-violation-reports`: List of reported violations

## Development

### Prerequisites
- Clarinet CLI tool
- Node.js and npm
- Stacks wallet for testing

### Installation
```bash
cd Buildix
npm install
```

### Testing
```bash
clarinet check
clarinet test
npm test
```

### Deployment
```bash
clarinet deploy --testnet
```

## Benefits

### For Government
- Increased transparency and accountability
- Reduced administrative overhead
- Improved record keeping and organization
- Enhanced public trust through openness
- Better enforcement and compliance tracking

### For Property Owners
- Permanent, verifiable construction records
- Faster permit processing and approvals
- Clear inspection requirements and scheduling
- Protection against fraudulent permits
- Increased property value through verified compliance

### For the Community
- Public access to construction information
- Ability to verify neighbor compliance
- Transparent development tracking
- Reduced construction fraud and violations
- Improved building safety standards

## Compliance Features

- **Building Code Compliance**: Ensures adherence to local building codes
- **Safety Standards**: Tracks compliance with safety regulations
- **Environmental Rules**: Records environmental impact assessments
- **Zoning Compliance**: Verifies conformance with zoning requirements
- **Historic Preservation**: Special handling for historic properties

## Contributing

We welcome contributions to improve building permit transparency! Please:

1. Fork the repository
2. Create a feature branch
3. Write tests for your changes
4. Ensure all tests pass with `clarinet check`
5. Submit a pull request

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Disclaimer

Buildix is designed to enhance building permit transparency and public access to construction information. Users should verify critical information through official channels. The system is designed to complement, not replace, existing government permitting systems.

## Support

For questions, issues, or contributions, please open an issue on our GitHub repository or contact our development team.

---

*Building transparent, accountable construction governance through blockchain technology.*