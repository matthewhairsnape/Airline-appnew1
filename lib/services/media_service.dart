import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

/// Service for handling image and video uploads
class MediaService {
  static final ImagePicker _imagePicker = ImagePicker();
  
  /// Pick image from gallery or camera
  static Future<String?> pickImage({bool fromCamera = false}) async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: fromCamera ? ImageSource.camera : ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );
      
      if (image != null) {
        // Save to app directory
        final String fileName = 'feedback_image_${DateTime.now().millisecondsSinceEpoch}.jpg';
        final Directory appDir = await getApplicationDocumentsDirectory();
        final String filePath = path.join(appDir.path, 'feedback_images', fileName);
        
        // Create directory if it doesn't exist
        await Directory(path.dirname(filePath)).create(recursive: true);
        
        // Copy file to app directory
        final File savedFile = await File(image.path).copy(filePath);
        
        debugPrint('✅ Image saved: $filePath');
        return filePath;
      }
      
      return null;
    } catch (e) {
      debugPrint('❌ Error picking image: $e');
      return null;
    }
  }
  
  /// Record video
  static Future<String?> recordVideo() async {
    try {
      final XFile? video = await _imagePicker.pickVideo(
        source: ImageSource.camera,
        maxDuration: const Duration(minutes: 2), // Limit to 2 minutes
      );
      
      if (video != null) {
        // Save to app directory
        final String fileName = 'feedback_video_${DateTime.now().millisecondsSinceEpoch}.mp4';
        final Directory appDir = await getApplicationDocumentsDirectory();
        final String filePath = path.join(appDir.path, 'feedback_videos', fileName);
        
        // Create directory if it doesn't exist
        await Directory(path.dirname(filePath)).create(recursive: true);
        
        // Copy file to app directory
        final File savedFile = await File(video.path).copy(filePath);
        
        debugPrint('✅ Video saved: $filePath');
        return filePath;
      }
      
      return null;
    } catch (e) {
      debugPrint('❌ Error recording video: $e');
      return null;
    }
  }
  
  /// Get media file info
  static Future<Map<String, dynamic>?> getMediaInfo(String filePath) async {
    try {
      final File file = File(filePath);
      if (!await file.exists()) return null;
      
      final int fileSizeBytes = await file.length();
      final DateTime lastModified = await file.lastModified();
      final String fileName = path.basename(filePath);
      final String extension = path.extension(filePath).toLowerCase();
      
      return {
        'fileName': fileName,
        'filePath': filePath,
        'fileSize': fileSizeBytes,
        'fileSizeMB': (fileSizeBytes / (1024 * 1024)).toStringAsFixed(2),
        'lastModified': lastModified.toIso8601String(),
        'extension': extension,
        'isImage': ['.jpg', '.jpeg', '.png', '.gif'].contains(extension),
        'isVideo': ['.mp4', '.mov', '.avi', '.mkv'].contains(extension),
      };
    } catch (e) {
      debugPrint('❌ Error getting media info: $e');
      return null;
    }
  }
  
  /// Delete media file
  static Future<bool> deleteMedia(String filePath) async {
    try {
      final File file = File(filePath);
      if (await file.exists()) {
        await file.delete();
        debugPrint('✅ Media deleted: $filePath');
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('❌ Error deleting media: $e');
      return false;
    }
  }
}
