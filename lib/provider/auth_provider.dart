import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:airline_app/services/push_notification_service.dart';
import 'package:airline_app/services/supabase_service.dart';

// User model
class User {
  final String id;
  final String? email;
  final String? name;
  final String? displayName;
  final String? avatarUrl;
  final String? phone;
  final String? role;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  User({
    required this.id,
    this.email,
    this.name,
    this.displayName,
    this.avatarUrl,
    this.phone,
    this.role,
    this.createdAt,
    this.updatedAt,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] ?? '',
      email: json['email'],
      name: json['name'],
      displayName: json['display_name'],
      avatarUrl: json['avatar_url'],
      phone: json['phone'],
      role: json['role'] ?? 'passenger',
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'name': name,
      'display_name': displayName,
      'avatar_url': avatarUrl,
      'phone': phone,
      'role': role,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }
}

// Auth state
@immutable
class AuthState {
  final AsyncValue<User?> user;
  final bool isInitialized;

  const AuthState({
    this.user = const AsyncValue.data(null),
    this.isInitialized = false,
  });

  AuthState copyWith({
    AsyncValue<User?>? user,
    bool? isInitialized,
  }) {
    return AuthState(
      user: user ?? this.user,
      isInitialized: isInitialized ?? this.isInitialized,
    );
  }

  // Add when method for compatibility
  T when<T>({
    required T Function(User? data) data,
    required T Function() loading,
    required T Function(Object error, StackTrace stackTrace) error,
  }) {
    return user.when(
      data: data,
      loading: loading,
      error: error,
    );
  }
}

// Auth notifier
class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier() : super(const AuthState()) {
    _initialize();
  }

  // Use SupabaseService.client (ensures initialize() was called)
  final SupabaseClient _supabase = SupabaseService.client;

  Future<void> _initialize() async {
    try {
      debugPrint('🔧 Initializing authentication...');

      // Check if Supabase is initialized
      if (!SupabaseService.isInitialized) {
        debugPrint('❌ Supabase not initialized during auth initialization');
        state = state.copyWith(
          user:
              AsyncValue.error('Supabase not initialized', StackTrace.current),
          isInitialized: true,
        );
        return;
      }

      debugPrint('✅ Supabase is initialized, setting up auth listeners...');

      // Listen to auth state changes
      _supabase.auth.onAuthStateChange.listen((data) async {
        debugPrint('🔄 Auth state changed: ${data.event}');

        final session = data.session;
        final authUser = session?.user;

        if (authUser != null) {
          debugPrint('👤 User found in session: ${authUser.id}');
          try {
            // Try to find profile by id first
            var userData = await _supabase
                .from('users')
                .select()
                .eq('id', authUser.id)
                .maybeSingle();

            // Fallback: find by email
            if (userData == null) {
              final email = authUser.email;
              if (email != null && email.isNotEmpty) {
                userData = await _supabase
                    .from('users')
                    .select()
                    .eq('email', email)
                    .maybeSingle();
              }
            }

            if (userData == null) {
              debugPrint(
                  '➕ No profile found — creating new profile for ${authUser.id}');

              final userDataToInsert = {
                'id': authUser.id,
                'email': authUser.email,
                'name': authUser.userMetadata?['name'] ??
                    authUser.email?.split('@').first,
                'display_name': authUser.userMetadata?['display_name'] ??
                    authUser.email?.split('@').first,
                'role': 'passenger',
                'created_at': DateTime.now().toIso8601String(),
                'updated_at': DateTime.now().toIso8601String(),
              };

              try {
                // This request will include JWT because we are inside an authenticated session change event
                final inserted = await _supabase
                    .from('users')
                    .insert(userDataToInsert)
                    .select()
                    .single();
                debugPrint('✅ Created user profile: ${inserted['id']}');
                await _loadUserData(inserted['id']);
              } catch (e, st) {
                debugPrint('❌ Failed to create profile in listener: $e\n$st');
                // Try to recover by loading any existing profile
                final existing = await () async {
                  final email = authUser.email;
                  if (email != null && email.isNotEmpty) {
                    return await _supabase
                        .from('users')
                        .select()
                        .eq('email', email)
                        .maybeSingle();
                  }
                  return null;
                }();
                if (existing != null) {
                  await _loadUserData(existing['id']);
                } else {
                  // set state to unauthenticated but initialized
                  state = state.copyWith(
                      user: const AsyncValue.data(null), isInitialized: true);
                }
              }
            } else {
              debugPrint('✅ Profile found, loading user data');
              await _loadUserData(userData['id']);
            }
          } catch (e, st) {
            // Try to recover by loading any existing profile (by email)
            Map<String, dynamic>? existing;
            final emailForRecovery = authUser.email;
            if (emailForRecovery != null && emailForRecovery.isNotEmpty) {
              try {
                existing = await _supabase
                    .from('users')
                    .select()
                    .eq('email', emailForRecovery)
                    .maybeSingle();
              } catch (e, st) {
                debugPrint(
                    '❌ Error checking existing user by email during recovery: $e\n$st');
                existing = null;
              }
            } else {
              existing = null;
            }

            if (existing != null) {
              await _loadUserData(existing['id']);
            } else {
              // set state to unauthenticated but initialized
              state = state.copyWith(
                  user: const AsyncValue.data(null), isInitialized: true);
            }
          }
        } else {
          debugPrint('👤 No user in session');
          state = state.copyWith(
              user: const AsyncValue.data(null), isInitialized: true);
        }
      });

      // Check if user is already signed in
      final session = _supabase.auth.currentSession;
      if (session?.user != null) {
        debugPrint('👤 Found existing session for user: ${session!.user.id}');
        // Try to find user by Auth ID first, then by email as fallback
        var userData = await _supabase
            .from('users')
            .select()
            .eq('id', session.user.id)
            .maybeSingle();
        if (userData == null) {
          final email = session.user.email;
          if (email != null && email.isNotEmpty) {
            userData = await _supabase
                .from('users')
                .select()
                .eq('email', email)
                .maybeSingle();
          }
        }

        if (userData != null) {
          await _loadUserData(userData['id']);
        } else {
          debugPrint('❌ User profile not found in database at startup');
          // The onAuthStateChange listener will create the profile if/when it can
          state = state.copyWith(isInitialized: true);
        }
      } else {
        debugPrint('👤 No existing session found');
        state = state.copyWith(isInitialized: true);
      }

      debugPrint('✅ Authentication initialization complete');
    } catch (e, st) {
      debugPrint('❌ Error initializing auth: $e\n$st');
      state = state.copyWith(
        user: AsyncValue.error(e, StackTrace.current),
        isInitialized: true,
      );
    }
  }

  Future<void> _loadUserData(String userId) async {
    try {
      state = state.copyWith(user: const AsyncValue.loading());

      // Get user data from Supabase
      final response =
          await _supabase.from('users').select().eq('id', userId).single();

      final user = User.fromJson(response);

      // Save FCM token for the user (non-fatal)
      try {
        await PushNotificationService.saveTokenForUser(userId);
      } catch (e) {
        debugPrint('⚠️ Failed to save FCM token (non-fatal): $e');
      }

      // Save user data to SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('userData', json.encode(user.toJson()));
      await prefs.setString(
          'token', _supabase.auth.currentSession?.accessToken ?? '');
      await prefs.setInt(
          'lastAccessTime', DateTime.now().millisecondsSinceEpoch);

      state = state.copyWith(
        user: AsyncValue.data(user),
        isInitialized: true,
      );
    } catch (e, st) {
      debugPrint('Error loading user data: $e\n$st');
      state = state.copyWith(
        user: AsyncValue.error(e, StackTrace.current),
        isInitialized: true,
      );
    }
  }

  // signUp: only create profile immediately if session/token exists
  // otherwise rely on auth listener to create the profile once the session is available
  Future<void> signUp({
    required String email,
    required String password,
    String? fullName,
  }) async {
    try {
      debugPrint('📝 Attempting to sign up with email: $email');
      state = state.copyWith(user: const AsyncValue.loading());

      // Check if Supabase is initialized
      if (!SupabaseService.isInitialized) {
        throw Exception('Supabase not initialized. Please restart the app.');
      }

      // Sign up with Supabase Auth
      final response = await _supabase.auth.signUp(
        email: email,
        password: password,
      );

      debugPrint(
          '📝 Sign up response: user=${response.user?.id} sessionExists=${response.session != null}');

      if (response.user != null) {
        // If signUp returned a session (JWT), we can safely create the profile immediately
        final session = response.session;
        if (session != null && (session.accessToken?.isNotEmpty ?? false)) {
          debugPrint(
              '🔐 Session present after signUp — creating profile immediately');

          final userData = {
            'id': response.user!.id,
            'email': email,
            'name': fullName,
            'display_name': fullName,
            'role': 'passenger',
            'created_at': DateTime.now().toIso8601String(),
            'updated_at': DateTime.now().toIso8601String(),
          };

          try {
            final insertedUser = await _supabase
                .from('users')
                .insert(userData)
                .select()
                .single();
            debugPrint(
                '✅ User profile created in database with ID: ${insertedUser['id']}');

            // Load user data (this will also save FCM token)
            await _loadUserData(insertedUser['id']);
            debugPrint('✅ Sign up successful (immediate profile creation)');
            return;
          } catch (e, st) {
            debugPrint(
                '❌ Error creating user profile immediately after signUp: $e\n$st');
            // Fall through: let the auth listener create the profile when session becomes active or if some race happened
          }
        }

        // If there's no session (common when email confirmation is required), don't attempt to insert as anon.
        debugPrint(
            'ℹ️ No session/token after signUp — deferring profile creation to auth listener');
        return;
      } else {
        throw Exception('Failed to create user account - no user returned');
      }
    } catch (e, st) {
      debugPrint('❌ Error during sign up: $e\n$st');
      state = state.copyWith(
        user: AsyncValue.error(e, StackTrace.current),
      );
      rethrow;
    }
  }

  Future<void> signIn({
    required String email,
    required String password,
  }) async {
    try {
      debugPrint('🔐 Attempting to sign in with email: $email');
      state = state.copyWith(user: const AsyncValue.loading());

      // Check if Supabase is initialized
      if (!SupabaseService.isInitialized) {
        throw Exception('Supabase not initialized. Please restart the app.');
      }

      // Sign in with Supabase Auth
      final response = await _supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );

      debugPrint('🔐 Sign in response: ${response.user?.id}');

      if (response.user != null) {
        // Try to find user by Auth ID first, then by email as fallback
        var userData = await _supabase
            .from('users')
            .select()
            .eq('id', response.user!.id)
            .maybeSingle();

        if (userData == null && email.isNotEmpty) {
          // Fallback: find by email
          userData = await _supabase
              .from('users')
              .select()
              .eq('email', email)
              .maybeSingle();
        }

        if (userData != null) {
          // Load user data (this will also save FCM token)
          await _loadUserData(userData['id']);
          debugPrint('✅ Sign in successful');
        } else {
          throw Exception('User profile not found in database');
        }
      } else {
        throw Exception('Failed to sign in - no user returned');
      }
    } catch (e, st) {
      debugPrint('❌ Error during sign in: $e\n$st');
      state = state.copyWith(
        user: AsyncValue.error(e, StackTrace.current),
      );
      rethrow;
    }
  }

  /// Sign in with Apple
  Future<void> signInWithApple({
    required String idToken,
    required String accessToken,
    String? email,
    String? fullName,
  }) async {
    try {
      debugPrint('🍎 Attempting Apple Sign-In');
      state = state.copyWith(user: const AsyncValue.loading());

      // Check if Supabase is initialized
      if (!SupabaseService.isInitialized) {
        throw Exception('Supabase not initialized. Please restart the app.');
      }

      // Sign in with Supabase using Apple credentials
      final response = await _supabase.auth.signInWithIdToken(
        provider: OAuthProvider.apple,
        idToken: idToken,
        accessToken: accessToken,
      );

      debugPrint('🍎 Apple Sign-In response: ${response.user?.id}');

      if (response.user != null) {
        // Check if user profile exists
        var userData = await _supabase
            .from('users')
            .select()
            .eq('id', response.user!.id)
            .maybeSingle();

        if (userData == null) {
          // Create user profile if it doesn't exist
          debugPrint('🍎 Creating new user profile for Apple Sign-In');

          final userProfile = {
            'id': response.user!.id,
            'email': email ?? response.user!.email,
            'display_name': fullName ?? email ?? 'Apple User',
            'avatar_url': null,
            'created_at': DateTime.now().toIso8601String(),
            'updated_at': DateTime.now().toIso8601String(),
          };

          await _supabase.from('users').insert(userProfile);
          userData = userProfile;
        }

        // Load user data
        await _loadUserData(userData['id']);
        debugPrint('✅ Apple Sign-In successful');
      } else {
        throw Exception('Failed to sign in with Apple - no user returned');
      }
    } catch (e, st) {
      debugPrint('❌ Error during Apple Sign-In: $e\n$st');
      state = state.copyWith(
        user: AsyncValue.error(e, StackTrace.current),
      );
      rethrow;
    }
  }

  Future<void> signOut() async {
    try {
      // Clear FCM token
      await PushNotificationService.clearToken();

      // Sign out from Supabase
      await _supabase.auth.signOut();

      // Clear local storage
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();

      state = state.copyWith(
        user: const AsyncValue.data(null),
      );
    } catch (e, st) {
      debugPrint('Error during sign out: $e\n$st');
      rethrow;
    }
  }

  Future<void> resetPassword(String email) async {
    try {
      await _supabase.auth.resetPasswordForEmail(email);
    } catch (e, st) {
      debugPrint('Error resetting password: $e\n$st');
      rethrow;
    }
  }

  Future<void> updateProfile({
    String? name,
    String? displayName,
    String? phone,
    String? avatarUrl,
  }) async {
    try {
      final currentUser = state.user.value;
      if (currentUser == null) return;

      final updates = <String, dynamic>{
        'updated_at': DateTime.now().toIso8601String(),
      };

      if (name != null) updates['name'] = name;
      if (displayName != null) updates['display_name'] = displayName;
      if (phone != null) updates['phone'] = phone;
      if (avatarUrl != null) updates['avatar_url'] = avatarUrl;

      await _supabase.from('users').update(updates).eq('id', currentUser.id);

      // Reload user data
      await _loadUserData(currentUser.id);
    } catch (e, st) {
      debugPrint('Error updating profile: $e\n$st');
      rethrow;
    }
  }
}

// Provider
final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier();
});
