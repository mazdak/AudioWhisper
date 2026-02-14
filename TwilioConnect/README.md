# TwilioConnect

A modern iOS app for SMS messaging and voice calls powered by the Twilio REST API.

## Requirements

- iOS 17.0+
- Xcode 15.0+
- Swift 5.9+
- A Twilio account with Account SID and Auth Token

## Project Structure

```
TwilioConnect/
├── App/                          # App entry point and root navigation
│   ├── TwilioConnectApp.swift    # @main app struct
│   └── ContentView.swift         # Tab-based root view
├── Core/                         # Shared infrastructure layer
│   ├── Network/
│   │   ├── TwilioAPIClient.swift # Twilio REST API client (actor)
│   │   └── NetworkError.swift    # Typed error handling
│   ├── Keychain/
│   │   └── KeychainManager.swift # Secure credential storage
│   └── Models/
│       ├── TwilioCredentials.swift
│       ├── Message.swift         # SMS message + conversation models
│       ├── PhoneCall.swift       # Call record + phone number models
│       └── TwilioResponses.swift # API response DTOs
├── Features/                     # Feature modules
│   ├── Settings/
│   │   ├── SettingsView.swift    # Credential config UI
│   │   └── SettingsViewModel.swift
│   ├── Messaging/
│   │   ├── Views/
│   │   │   ├── ConversationsListView.swift
│   │   │   ├── ConversationView.swift
│   │   │   ├── MessageBubbleView.swift
│   │   │   └── ComposeMessageView.swift
│   │   └── ViewModels/
│   │       ├── ConversationsViewModel.swift
│   │       └── ConversationDetailViewModel.swift
│   └── Calling/
│       ├── Views/
│       │   ├── PhoneTabView.swift
│       │   ├── DialerView.swift
│       │   ├── ActiveCallView.swift
│       │   └── CallHistoryView.swift
│       ├── ViewModels/
│       │   └── CallViewModel.swift
│       └── Services/
│           └── CallManager.swift  # CallKit integration
├── Shared/
│   ├── Components/
│   │   ├── ContactAvatar.swift
│   │   └── PhoneNumberField.swift
│   └── Extensions/
│       ├── DateFormatter+Twilio.swift
│       └── String+Phone.swift
└── Resources/
    └── Info.plist
```

## Architecture

- **MVVM** with `@Observable` / `ObservableObject` view models
- **Actor-based** networking (`TwilioAPIClient` is a Swift actor for thread safety)
- **Keychain** storage for credentials (no plaintext storage)
- **CallKit** integration for native iOS call UI
- **Feature-based** module organization

## Setup

1. Open the project in Xcode
2. Build and run on a device or simulator
3. Go to **Settings** tab
4. Enter your Twilio **Account SID** (starts with `AC`) and **Auth Token**
5. Tap **Verify & Save**
6. Select your Twilio phone number

## Features

### SMS Messaging
- View all conversations grouped by contact
- Send and receive SMS messages
- Compose new messages to any phone number
- Auto-refresh for new messages (15-second polling)
- Message delivery status indicators

### Voice Calls
- Dial pad for making outbound calls
- CallKit integration for native call UI
- Call history with status and duration
- Incoming call support via CallKit

## API Usage

This app uses the [Twilio REST API](https://www.twilio.com/docs/usage/api):
- `GET /Messages.json` — Fetch SMS messages
- `POST /Messages.json` — Send SMS
- `GET /Calls.json` — Fetch call history
- `POST /Calls.json` — Initiate outbound call
- `GET /IncomingPhoneNumbers.json` — List account phone numbers
- `GET /Accounts/{SID}.json` — Verify credentials

## Security

- Credentials are stored in the iOS Keychain, never in UserDefaults or plaintext
- API calls use HTTP Basic Auth over HTTPS
- No credentials are logged or transmitted to third parties
