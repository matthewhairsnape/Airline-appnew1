# Authentication Implementation

This document describes the email/password authentication implementation using Supabase.

## Overview

The app now requires users to authenticate with email and password before accessing the main features. The authentication is handled through Supabase Auth with the following components:

## Components

### 1. Supabase Service (`lib/services/supabase_service.dart`)
- Handles all Supabase authentication operations
- Methods: `signUp()`, `signIn()`, `signOut()`, `resetPassword()`
- Manages user profile creation, retrieval, and updates
- Comprehensive data saving methods: `saveUserDataToSupabase()`, `updateUserProfile()`
- Integrates with the existing Supabase database schema

### 2. Data Sync Service (`lib/services/data_sync_service.dart`)
- Ensures all user data is properly saved to Supabase
- Handles bidirectional data synchronization (local ↔ Supabase)
- Automatic sync checking and force sync capabilities
- Comprehensive data persistence with error handling

### 3. Authentication Provider (`lib/provider/auth_provider.dart`)
- Manages authentication state using Riverpod
- Handles user data persistence in SharedPreferences
- Automatically saves all user data to Supabase
- Provides reactive authentication state to the UI
- Manages token refresh and session persistence

### 4. User Data Provider (`lib/provider/user_data_provider.dart`)
- Enhanced with automatic Supabase synchronization
- Updates user data both locally and in Supabase
- Provides methods for data updates and synchronization
- Ensures data consistency across all app components

### 5. Login Screen (`lib/screen/logIn/log_in.dart`)
- Beautiful login/signup form with email and password fields
- Form validation for email format and password requirements
- Toggle between login and signup modes
- Forgot password functionality
- Loading states and error handling

### 6. Authentication Wrapper (`lib/main.dart`)
- `AuthWrapper` widget that checks authentication state
- Automatically redirects to login or main app based on auth status
- Handles loading states during authentication checks

## Features

### Login/Signup
- **Email validation**: Proper email format checking
- **Password requirements**: Minimum 6 characters
- **Full name**: Optional during signup
- **Form validation**: Real-time validation with error messages

### User Experience
- **Persistent sessions**: Users stay logged in for 24 hours
- **Automatic redirects**: Seamless navigation based on auth state
- **Loading indicators**: Visual feedback during authentication
- **Error handling**: User-friendly error messages

### Data Persistence
- **Automatic Supabase Sync**: All user data is automatically saved to Supabase
- **Bidirectional Sync**: Data syncs both ways (local ↔ Supabase)
- **Real-time Updates**: User data changes are immediately persisted
- **Offline Support**: Local storage with sync when online
- **Data Integrity**: Comprehensive error handling and retry mechanisms

### Security
- **Supabase Auth**: Industry-standard authentication
- **JWT tokens**: Secure token-based authentication
- **Password hashing**: Handled by Supabase
- **Session management**: Automatic token refresh
- **Data Encryption**: All data encrypted in transit and at rest

## Database Schema

The authentication uses the existing `users` table in Supabase:

```sql
CREATE TABLE users (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  email TEXT,
  phone TEXT,
  display_name TEXT,
  avatar_url TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);
```

## Usage

### Running the App
The app requires Supabase credentials to be passed as environment variables:

```bash
flutter run --dart-define=SUPABASE_URL=your_supabase_url --dart-define=SUPABASE_ANON_KEY=your_supabase_anon_key
```

Or use the provided `run.sh` script:
```bash
./run.sh
```

### Authentication Flow
1. App starts and checks for existing authentication
2. If not authenticated, shows login screen
3. User can sign up or sign in with email/password
4. Upon successful authentication, user is redirected to main app
5. User can sign out from profile screen
6. Sign out clears all data and returns to login screen

## Configuration

### Supabase Setup
1. Ensure your Supabase project has the `users` table created
2. Enable email authentication in Supabase Auth settings
3. Configure email templates for password reset (optional)

### Environment Variables
- `SUPABASE_URL`: Your Supabase project URL
- `SUPABASE_ANON_KEY`: Your Supabase anonymous key

## Error Handling

The implementation includes comprehensive error handling:
- Network connectivity issues
- Invalid credentials
- Email already exists during signup
- Password reset failures
- Database connection issues

All errors are displayed to users with appropriate messages and fallback behaviors.

## Future Enhancements

Potential improvements for the authentication system:
- Social login (Google, Apple, etc.)
- Biometric authentication
- Two-factor authentication
- Remember me functionality
- Account verification via email
- Password strength indicators
