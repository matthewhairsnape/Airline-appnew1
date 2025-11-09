// AWS Upload Service temporarily disabled due to missing aws_s3_api package
// TODO: Re-enable when aws_s3_api package is added back or replaced with alternative

import 'dart:io';
// import 'package:aws_s3_api/s3-2006-03-01.dart';
import 'package:path/path.dart' as path;

class AwsUploadService {
  final String _accessKeyId;
  final String _secretAccessKey;
  final String _region;
  final String _bucketName;
  // late S3 _s3;

  AwsUploadService({
    required String accessKeyId,
    required String secretAccessKey,
    required String region,
    required String bucketName,
  })  : _accessKeyId = accessKeyId,
        _secretAccessKey = secretAccessKey,
        _region = region,
        _bucketName = bucketName {
    // _initializeS3Client();
  }

  // void _initializeS3Client() {
  //   _s3 = S3(
  //     region: _region,
  //     credentials: AwsClientCredentials(
  //       accessKey: _accessKeyId,
  //       secretKey: _secretAccessKey,
  //     ),
  //   );
  // }

  Future<String> uploadFile(File file, String folderName) async {
    // Temporarily return a placeholder URL
    // TODO: Implement actual upload when AWS package is available
    final fileName = path.basename(file.path);
    final destination = '$folderName/$fileName';
    return 'https://placeholder-url.com/$destination';

    // try {
    //   final fileName = path.basename(file.path);
    //   final destination = '$folderName/$fileName';
    //   final fileExtension = path.extension(file.path).toLowerCase();

    //   String contentType;
    //   if (fileExtension == '.mp4' || fileExtension == '.mov') {
    //     contentType = 'video/mp4';
    //   } else if (fileExtension == '.jpg' || fileExtension == '.jpeg') {
    //     contentType = 'image/jpeg';
    //   } else if (fileExtension == '.png') {
    //     contentType = 'image/png';
    //   } else {
    //     contentType = 'application/octet-stream';
    //   }

    //   await _s3.putObject(
    //     bucket: _bucketName,
    //     key: destination,
    //     body: file.readAsBytesSync(),
    //     contentType: contentType,
    //   );

    //   final url = 'https://d2ktq59qt1f9bd.cloudfront.net/$destination';
    //   return url;
    // } catch (e) {
    //   throw Exception('Failed to upload file: $e');
    // }
  }
}
