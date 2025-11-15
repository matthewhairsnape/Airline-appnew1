import 'dart:io';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:path/path.dart' as path;
import 'package:mime/mime.dart';

/// Service for uploading media files to Supabase Storage
class SupabaseStorageService {
  static final _client = Supabase.instance.client;
  
  /// Default bucket name for feedback media
  static const String _defaultBucket = 'feedback-media';
  
  /// Upload a single media file to Supabase Storage
  /// Returns the public URL of the uploaded file
  static Future<String?> uploadMediaFile({
    required File file,
    required String userId,
    required String journeyId,
    String? phase,
    String? folder,
  }) async {
    try {
      debugPrint('📤 Starting media upload...');
      debugPrint('   File: ${file.path}');
      debugPrint('   User ID: $userId');
      debugPrint('   Journey ID: $journeyId');
      
      // Check if file exists
      if (!await file.exists()) {
        debugPrint('❌ File does not exist: ${file.path}');
        return null;
      }
      
      // Get file info
      final fileName = path.basename(file.path);
      final fileExtension = path.extension(fileName).toLowerCase();
      final fileSize = await file.length();
      
      debugPrint('   File name: $fileName');
      debugPrint('   File size: ${(fileSize / 1024 / 1024).toStringAsFixed(2)} MB');
      
      // Validate file size (max 50MB)
      const maxSize = 50 * 1024 * 1024; // 50MB
      if (fileSize > maxSize) {
        debugPrint('❌ File too large: ${(fileSize / 1024 / 1024).toStringAsFixed(2)} MB (max: 50 MB)');
        throw Exception('File size exceeds 50MB limit');
      }
      
      // Validate file type
      final mimeType = lookupMimeType(file.path);
      final isImage = ['.jpg', '.jpeg', '.png', '.gif', '.webp'].contains(fileExtension);
      final isVideo = ['.mp4', '.mov', '.avi', '.mkv', '.webm'].contains(fileExtension);
      
      if (!isImage && !isVideo) {
        debugPrint('❌ Unsupported file type: $fileExtension');
        throw Exception('Unsupported file type. Only images and videos are allowed.');
      }
      
      // Create unique file name with timestamp
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final uniqueFileName = '${userId}_${journeyId}_${timestamp}_$fileName';
      
      // Build storage path
      // Format: feedback-media/{userId}/{journeyId}/{phase?}/{fileName}
      final storagePath = folder != null
          ? '$folder/$userId/$journeyId/$phase/$uniqueFileName'
          : '$userId/$journeyId/$phase/$uniqueFileName';
      
      debugPrint('   Storage path: $storagePath');
      
      // Upload to Supabase Storage
      // The upload method accepts a File object directly
      final response = await _client.storage
          .from(_defaultBucket)
          .upload(
            storagePath,
            file,
            fileOptions: FileOptions(
              contentType: mimeType ?? 'application/octet-stream',
              upsert: false, // Don't overwrite existing files
            ),
          );
      
      debugPrint('✅ File uploaded successfully');
      debugPrint('   Response: $response');
      
      // Get public URL
      final publicUrl = _client.storage
          .from(_defaultBucket)
          .getPublicUrl(storagePath);
      
      debugPrint('   Public URL: $publicUrl');
      
      return publicUrl;
    } catch (e, stackTrace) {
      debugPrint('❌ Error uploading media file: $e');
      debugPrint('   Stack trace: $stackTrace');
      return null;
    }
  }
  
  /// Upload multiple media files
  /// Returns a map of file paths to their public URLs
  static Future<Map<String, String>> uploadMediaFiles({
    required List<String> filePaths,
    required String userId,
    required String journeyId,
    String? phase,
    String? folder,
  }) async {
    final results = <String, String>{};
    
    for (final filePath in filePaths) {
      try {
        final file = File(filePath);
        if (!await file.exists()) {
          debugPrint('⚠️ File not found: $filePath');
          continue;
        }
        
        final url = await uploadMediaFile(
          file: file,
          userId: userId,
          journeyId: journeyId,
          phase: phase,
          folder: folder,
        );
        
        if (url != null) {
          results[filePath] = url;
        }
      } catch (e) {
        debugPrint('❌ Error uploading file $filePath: $e');
      }
    }
    
    return results;
  }
  
  /// Delete a media file from Supabase Storage
  static Future<bool> deleteMediaFile(String storagePath) async {
    try {
      await _client.storage
          .from(_defaultBucket)
          .remove([storagePath]);
      
      debugPrint('✅ Media file deleted: $storagePath');
      return true;
    } catch (e) {
      debugPrint('❌ Error deleting media file: $e');
      return false;
    }
  }
  
  /// Get public URL for a file in storage
  static String getPublicUrl(String storagePath) {
    return _client.storage
        .from(_defaultBucket)
        .getPublicUrl(storagePath);
  }
  
  /// Check if storage bucket exists, create if not
  static Future<bool> ensureBucketExists() async {
    try {
      // Try to list files in the bucket (this will fail if bucket doesn't exist)
      await _client.storage.from(_defaultBucket).list();
      debugPrint('✅ Storage bucket exists: $_defaultBucket');
      return true;
    } catch (e) {
      debugPrint('⚠️ Storage bucket may not exist: $_defaultBucket');
      debugPrint('   Error: $e');
      debugPrint('💡 Please create the bucket in Supabase Dashboard:');
      debugPrint('   1. Go to Storage in Supabase Dashboard');
      debugPrint('   2. Create a new bucket named: $_defaultBucket');
      debugPrint('   3. Set it to Public if you want public URLs');
      debugPrint('   4. Configure RLS policies as needed');
      return false;
    }
  }
}

