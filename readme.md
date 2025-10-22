# Airline Feedback Platform

A comprehensive Flutter application that enables real-time airline feedback and review collection from passengers. The platform provides airlines with instant insights into passenger experiences while allowing travelers to share their journey feedback in real-time.

## 🚀 Features

- **Real-time Feedback Collection**: Passengers can submit feedback during their journey
- **Airline Leaderboards**: Dynamic rankings based on verified passenger reviews
- **Multi-language Support**: Available in English, Spanish, and Chinese
- **Apple Sign-In Integration**: Secure authentication with Apple ID
- **Push Notifications**: Real-time updates and journey reminders
- **Boarding Pass Scanning**: QR code scanning for flight verification
- **Journey Tracking**: Complete flight experience monitoring
- **Media Upload**: Photo and video feedback support

## 🛠 Tech Stack

- **Frontend**: Flutter 3.5.3+ with Dart
- **State Management**: Riverpod
- **Backend**: Supabase (PostgreSQL, Auth, Real-time)
- **Authentication**: Apple Sign-In, Firebase Auth
- **Push Notifications**: Firebase Cloud Messaging
- **Localization**: Flutter Localizations
- **UI Components**: Custom design system with SF Pro fonts

## 📱 Quick Start

### Prerequisites

- Flutter SDK 3.5.3 or higher
- Xcode 14+ (for iOS development)
- Android Studio (for Android development)
- Supabase account
- Firebase project

### Installation

1. **Clone the repository**
   ```bash
   git clone https://github.com/your-username/airline-app.git
   cd airline-app
   ```

2. **Install dependencies**
   ```bash
   flutter pub get
   ```

3. **Configure environment**
   - Set up Supabase project and add configuration
   - Configure Firebase for push notifications
   - Set up Apple Sign-In credentials

4. **Run the application**
   ```bash
   flutter run
   ```

## 🏗 Project Structure

```
lib/
├── config/                 # Configuration files
├── controller/             # Business logic controllers
├── models/                 # Data models
├── provider/               # State management providers
├── screen/                 # UI screens organized by feature
│   ├── feed/              # Real-time feedback feed
│   ├── journey/           # Journey tracking and timeline
│   ├── leaderboard/       # Airline rankings and scoring
│   ├── login/             # Authentication screens
│   ├── profile/           # User profile management
│   ├── reviewsubmission/  # Review submission flow
│   └── settings/          # App settings and preferences
├── services/               # Core services and API integrations
├── utils/                  # Utility functions and helpers
└── widgets/                # Reusable UI components
```

## 🔧 Configuration

### Supabase Setup
1. Create a new Supabase project
2. Configure authentication providers
3. Set up database tables and RLS policies
4. Add environment variables

### Firebase Setup
1. Create Firebase project
2. Enable Cloud Messaging
3. Configure iOS and Android apps
4. Download configuration files

### Apple Sign-In
1. Configure Apple Developer account
2. Set up Sign in with Apple capability
3. Generate authentication keys
4. Configure redirect URLs

## 🏛 Architecture & Design

### Clean Architecture Principles
- **Feature-based organization**: Each feature is self-contained with its own providers, screens, and data models
- **Separation of concerns**: Clear distinction between business logic, data access, and UI components
- **Scalable structure**: Easy to add new features without affecting existing code
- **Consistent naming**: Standardized naming conventions across all modules

### State Management
- **Riverpod**: Modern state management with type-safe providers
- **Feature isolation**: Each feature manages its own state independently
- **Reactive updates**: Real-time data synchronization with Supabase

### Code Quality
- **Professional structure**: Enterprise-grade folder organization
- **Consistent theming**: Centralized theme management with Material 3 design
- **Type safety**: Strong typing with enums and generics
- **Clean imports**: Organized import statements with clear dependencies

## 📊 Key Features

### Real-time Feedback
- Live feedback collection during flights
- Categorized feedback (comfort, service, food, etc.)
- Photo and video attachments
- Seat-specific feedback

### Leaderboard System
- Dynamic airline rankings
- Category-based scoring
- Real-time updates
- Historical performance tracking

### Journey Management
- Flight tracking integration
- Boarding pass verification
- Timeline-based experience tracking
- Comprehensive feedback collection

## 🚀 Getting Started

1. **Development Setup**
   ```bash
   flutter doctor
   flutter pub get
   flutter run
   ```

2. **Build for Production**
   ```bash
   flutter build ios --release
   flutter build apk --release
   ```

## 📄 License

This project is proprietary software. All rights reserved.

## 🤝 Contributing

This is a private project. For access and contribution guidelines, please contact the development team.

## 📞 Support

For technical support or questions, please contact the development team or create an issue in the project repository.
