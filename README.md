# My Other App - Mobile Application

A modern Flutter mobile application for community and event management, enabling users to discover events, follow clubs, and engage with their community.

![Flutter](https://img.shields.io/badge/Flutter-3.6.0-02569B?logo=flutter)
![Dart](https://img.shields.io/badge/Dart-3.6.0-0175C2?logo=dart)
![License](https://img.shields.io/badge/License-Proprietary-red)

## 📱 Features

### Authentication
- **Google Sign-In** - Seamless authentication with Google accounts
- **Secure Token Storage** - JWT tokens stored securely using Flutter Secure Storage
- **Auto-login** - Persistent sessions with automatic token refresh

### Events
- **Event Discovery** - Browse events with "For You" and "Following" filters
- **Event Registration** - Register for events with in-app payment support
- **Event Details** - Rich event pages with date, location, fees, prizes, and more
- **Event Search** - Context-aware search with tab-based filtering
- **Past Events** - View attended events with certificates
- **Digital Tickets** - QR code tickets with Apple/Google Wallet integration

### Clubs
- **Club Profiles** - Detailed club pages with about, events, and ratings
- **Follow/Unfollow** - Follow clubs to get their events in your feed
- **Pin Clubs** - Pin favorite clubs for quick access
- **Hide Events** - Hide events from specific clubs
- **Club Search** - Search clubs by name

### User Profile
- **Profile Management** - View and edit user profile
- **Interests** - Select and manage interests for personalized recommendations
- **Registered Events** - Track upcoming and past event registrations

## 🏗️ Architecture

The app follows **Clean Architecture** principles with a feature-first organization:

```
lib/
├── app/                    # App configuration
│   └── router/             # Go Router navigation setup
├── common/                 # Shared models and widgets
│   ├── models/             # Data models (Event, User, etc.)
│   └── widgets/            # Reusable UI components
├── core/                   # Core infrastructure
│   ├── api/                # API helper and Dio configuration
│   ├── config/             # Environment configuration
│   ├── network/            # Network interceptors
│   ├── storage/            # Secure storage service
│   └── themes/             # App theming (colors, typography)
├── features/               # Feature modules
│   ├── auth/               # Authentication (login, onboarding)
│   ├── clubs/              # Club management
│   ├── events/             # Event management
│   ├── home/               # Home page with event feeds
│   ├── main/               # Main shell and navigation
│   └── profile/            # User profile
├── shared/                 # Shared utilities
│   └── widgets/            # Common widgets (EventCard, SearchDelegate, etc.)
└── main.dart               # App entry point
```

## 🛠️ Tech Stack

| Category | Technology |
|----------|------------|
| **Framework** | Flutter 3.6.0 |
| **State Management** | Riverpod 2.4 |
| **Navigation** | Go Router 14.0 |
| **Network** | Dio 5.8 |
| **Authentication** | Google Sign-In |
| **Storage** | Flutter Secure Storage |
| **UI** | Material Design 3, Shimmer, Cached Network Image |
| **Tickets** | QR Flutter, Flutter Wallet Card |

## 🚀 Getting Started

### Prerequisites

- Flutter SDK 3.6.0 or higher
- Dart SDK 3.6.0 or higher
- iOS: Xcode 15+ (for iOS builds)
- Android: Android Studio with SDK 33+

### Installation

1. **Clone the repository**
   ```bash
   git clone https://github.com/my-other-app/moa_mobileapp.git
   cd moa_mobileapp
   ```

2. **Install dependencies**
   ```bash
   flutter pub get
   ```

3. **Configure environment**
   ```bash
   cp .env.example .env
   # Edit .env with your API base URL and keys
   ```

4. **Generate code** (Riverpod, Envied)
   ```bash
   flutter pub run build_runner build --delete-conflicting-outputs
   ```

5. **Run the app**
   ```bash
   flutter run
   ```

### Environment Variables

Create a `.env` file in the project root:

```env
API_BASE_URL=https://api.myotherapp.com
GOOGLE_CLIENT_ID=your_google_client_id
```

## 📂 Key Files

| File | Description |
|------|-------------|
| `lib/main.dart` | App entry point with ProviderScope |
| `lib/app/router/app_router.dart` | Navigation routes configuration |
| `lib/core/api/api_helper.dart` | Dio HTTP client with interceptors |
| `lib/core/config/env/env.dart` | Environment configuration |
| `lib/shared/widgets/event_card.dart` | Reusable event card widget |
| `lib/shared/widgets/custom_search_delegate.dart` | Search functionality |

## 🎨 UI Components

### Event Card
Displays event information with poster, title, tags, and actions.

### Search Delegates
- `EventSearchDelegate` - Search events with tab-based filters
- `ClubSearchDelegate` - Search clubs only

### Shimmer Widgets
Loading placeholders for:
- Event lists
- Club details
- Profile sections

## 🔐 Security

- **Secure Storage** - Tokens stored in encrypted keychain/keystore
- **Auth Interceptor** - Automatic token injection and refresh

## 📱 Platform Support

| Platform | Status |
|----------|--------|
| iOS | ✅ Supported |
| Android | ✅ Supported |
| Web | 🔄 Partial |
| macOS | 🔄 Partial |
| Windows | 🔄 Partial |
| Linux | 🔄 Partial |

## 🧪 Testing

```bash
# Run unit tests
flutter test

# Run with coverage
flutter test --coverage
```

## 📦 Build

### Android
```bash
flutter build apk --release
flutter build appbundle --release
```

### iOS
```bash
flutter build ios --release
```

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit changes (`git commit -m 'Add amazing feature'`)
4. Push to branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## 📄 License

This project is proprietary software. All rights reserved.

---

**My Other App** - Connecting communities through events 🎉
