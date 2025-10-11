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
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at']) : null,
      updatedAt: json['updated_at'] != null ? DateTime.parse(json['updated_at']) : null,
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

  final SupabaseClient _supabase = Supabase.instance.client;

  Future<void> _initialize() async {
    try {
      debugPrint('🔧 Initializing authentication...');
      
      // Check if Supabase is initialized
      if (!SupabaseService.isInitialized) {
        debugPrint('❌ Supabase not initialized during auth initialization');
        state = state.copyWith(
          user: AsyncValue.error('Supabase not initialized', StackTrace.current),
          isInitialized: true,
        );
        return;
      }

      debugPrint('✅ Supabase is initialized, setting up auth listeners...');

      // Listen to auth state changes
      _supabase.auth.onAuthStateChange.listen((data) async {
        debugPrint('🔄 Auth state changed: ${data.event}');
        final session = data.session;
        if (session?.user != null) {
          debugPrint('👤 User found in session: ${session!.user.id}');
          // Try to find user by Auth ID first, then by email as fallback
          var userData = await _supabase
              .from('users')
              .select()
              .eq('id', session.user.id)
              .maybeSingle();
              
          if (userData == null) {
            // Fallback: find by email
            userData = await _supabase
                .from('users')
                .select()
                .eq('email', session.user.email!)
                .maybeSingle();
          }
              
          if (userData != null) {
            await _loadUserData(userData['id']);
          } else {
            debugPrint('❌ User profile not found in database');
            state = state.copyWith(
              user: const AsyncValue.data(null),
              isInitialized: true,
            );
          }
        } else {
          debugPrint('👤 No user in session');
          state = state.copyWith(
            user: const AsyncValue.data(null),
            isInitialized: true,
          );
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
          // Fallback: find by email
          userData = await _supabase
              .from('users')
              .select()
              .eq('email', session.user.email!)
              .maybeSingle();
        }
            
        if (userData != null) {
          await _loadUserData(userData['id']);
        } else {
          debugPrint('❌ User profile not found in database');
          state = state.copyWith(isInitialized: true);
        }
      } else {
        debugPrint('👤 No existing session found');
        state = state.copyWith(isInitialized: true);
      }
      
      debugPrint('✅ Authentication initialization complete');
    } catch (e) {
      debugPrint('❌ Error initializing auth: $e');
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
      final response = await _supabase
          .from('users')
          .select()
          .eq('id', userId)
          .single();

      final user = User.fromJson(response);
      
      // Save FCM token for the user
      await PushNotificationService.saveTokenForUser(userId);

      // Save user data to SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('userData', json.encode(user.toJson()));
      await prefs.setString('token', _supabase.auth.currentSession?.accessToken ?? '');
      await prefs.setInt('lastAccessTime', DateTime.now().millisecondsSinceEpoch);

      state = state.copyWith(
        user: AsyncValue.data(user),
        isInitialized: true,
      );
    } catch (e) {
      debugPrint('Error loading user data: $e');
      state = state.copyWith(
        user: AsyncValue.error(e, StackTrace.current),
        isInitialized: true,
      );
    }
  }

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

      debugPrint('📝 Sign up response: ${response.user?.id}');

      if (response.user != null) {
        // Create user profile in users table
        // Use the Auth user ID as the primary key to maintain consistency
        final userData = {
          'id': response.user!.id, // Use Auth user ID as primary key
          'email': email,
          'name': fullName,
          'display_name': fullName,
          'role': 'passenger',
          'created_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        };

        try {
          final insertedUser = await _supabase.from('users').insert(userData).select().single();
          debugPrint('✅ User profile created in database with ID: ${insertedUser['id']}');

          // Load user data (this will also save FCM token)
          await _loadUserData(insertedUser['id']);
          debugPrint('✅ Sign up successful');
        } catch (e) {
          debugPrint('❌ Error creating user profile: $e');
          // If insert fails, try to find existing user
          final existingUser = await _supabase
              .from('users')
              .select()
              .eq('email', email)
              .maybeSingle();
              
          if (existingUser != null) {
            debugPrint('✅ Found existing user profile');
            await _loadUserData(existingUser['id']);
            debugPrint('✅ Sign up successful (existing user)');
          } else {
            rethrow;
          }
        }
      } else {
        throw Exception('Failed to create user account - no user returned');
      }
    } catch (e) {
      debugPrint('❌ Error during sign up: $e');
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
            
        if (userData == null) {
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
    } catch (e) {
      debugPrint('❌ Error during sign in: $e');
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
    } catch (e) {
      debugPrint('Error during sign out: $e');
      rethrow;
    }
  }

  Future<void> resetPassword(String email) async {
    try {
      await _supabase.auth.resetPasswordForEmail(email);
    } catch (e) {
      debugPrint('Error resetting password: $e');
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

      await _supabase
          .from('users')
          .update(updates)
          .eq('id', currentUser.id);

      // Reload user data
      await _loadUserData(currentUser.id);
    } catch (e) {
      debugPrint('Error updating profile: $e');
      rethrow;
    }
  }
}

// Provider
final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier();
});