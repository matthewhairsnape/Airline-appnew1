import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'package:airline_app/screen/app_widgets/appbar_widget.dart';
import 'package:airline_app/screen/app_widgets/bottom_button_bar.dart';
import 'package:airline_app/screen/app_widgets/custom_icon_button.dart';
import 'package:airline_app/screen/app_widgets/custom_snackbar.dart';
import 'package:airline_app/screen/app_widgets/keyboard_dismiss_widget.dart';
import 'package:airline_app/screen/app_widgets/loading.dart';
import 'package:airline_app/screen/app_widgets/main_button.dart';
import 'package:airline_app/screen/reviewsubmission/widgets/comment_input_field.dart';
import 'package:airline_app/utils/global_variable.dart';
import 'package:image_picker/image_picker.dart';
import 'package:airline_app/provider/user_data_provider.dart';
import 'package:airline_app/utils/app_routes.dart';
import 'package:airline_app/utils/app_styles.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:airline_app/utils/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:airline_app/screen/app_widgets/aws_upload_service.dart';
import 'package:airline_app/utils/global_variable.dart' as aws_credentials;

class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  List<dynamic> airlineData = [];
  bool isLoading = false;
  final TextEditingController _bioController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _airlineController = TextEditingController();
  XFile? _selectedImage;
  String initialName = '';
  String initialBio = '';

  @override
  void dispose() {
    _nameController.dispose();
    _bioController.dispose();
    _airlineController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    final userData = ref.read(userDataProvider);
    initialName = userData?['userData']['name'] ?? '';
    initialBio = userData?['userData']['bio'] ?? '';
    _nameController.text = initialName;
    _bioController.text = initialBio;
    _airlineController.text = userData?['userData']['favoriteAirlines'] ?? '';
  }

  void reloadProfileImage() {
    setState(() {
      // Clear image cache to force reload
      final imageCache = PaintingBinding.instance.imageCache;
      imageCache.clear();
      imageCache.clearLiveImages();
    });
  }

  Future<String> _uploadImages(XFile? image) async {
    if (image == null) return '';
    final awsUploadService = AwsUploadService(
      accessKeyId: aws_credentials.accessKeyId,
      secretAccessKey: aws_credentials.secretAccessKey,
      region: aws_credentials.region,
      bucketName: aws_credentials.bucketName,
    );

    try {
      final uploadedUrl =
          await awsUploadService.uploadFile(File(image.path), 'avatar');
      return uploadedUrl;
    } catch (e) {
      if (mounted) {
        CustomSnackBar.error(context, "'Upload failed: $e'");
      }
      return '';
    }
  }

  Future<void> _pickImage() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image =
          await picker.pickImage(source: ImageSource.gallery).timeout(
        Duration(seconds: 10),
        onTimeout: () {
          throw TimeoutException('Image picker timed out');
        },
      );

      if (image != null) {
        // Clear existing image cache before setting new image
        final imageCache = ImageCache();
        imageCache.clear();
        imageCache.clearLiveImages();

        setState(() {
          _selectedImage = image;
        });
      }
    } on PlatformException catch (e) {
      if (e.code == 'already_active') {
        // Handle the case where image picker is already active
        debugPrint('Image picker is already active');
        return;
      }
      // Handle other platform exceptions
      debugPrint('Failed to pick image: ${e.message}');
    } catch (e) {
      // Handle other exceptions
      debugPrint('Error picking image: $e');
    }
  }

  void _editProfileFunction() async {
    if (!mounted) return;

    setState(() {
      isLoading = true;
    });

    try {
      final userData = ref.read(userDataProvider);
      String uploadedProfilePhoto = userData?['userData']['profilePhoto'] ?? '';

      if (_selectedImage != null) {
        uploadedProfilePhoto = await _uploadImages(_selectedImage);
      }

      final updateData = {
        'name': _nameController.text,
        'bio': _bioController.text,
        '_id': userData?['userData']['_id'],
        'favoriteAirline': _airlineController.text,
        'profilePhoto': uploadedProfilePhoto,
      };

      final response = await http.post(
        Uri.parse('$apiUrl/api/v1/editUser'),
        headers: {'Content-Type': 'application/json; charset=UTF-8'},
        body: json.encode(updateData),
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('userData', json.encode(responseData));

        ref.read(userDataProvider.notifier).setUserData(responseData);

        if (mounted) {
          setState(() {
            isLoading = false;
          });

          Navigator.pushReplacementNamed(context, AppRoutes.profilescreen);
          CustomSnackBar.success(context, "Successfully saved!");
        }
      } else {
        throw Exception('Failed to update profile');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
        CustomSnackBar.error(context, 'Update failed: ${e.toString()}');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final userData = ref.read(userDataProvider);
    return Stack(
      children: [
        KeyboardDismissWidget(
          child: Scaffold(
            appBar: AppbarWidget(
              title: AppLocalizations.of(context).translate('Edit Profile'),
              onBackPressed: () => Navigator.pop(context),
            ),
            body: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  children: [
                    SizedBox(
                      height: 20,
                    ),
                    Stack(
                      children: [
                        Container(
                          width: 100,
                          height: 100,
                          decoration: AppStyles.avatarDecoration,
                          child: CircleAvatar(
                            backgroundImage: _selectedImage != null
                                ? FileImage(File(_selectedImage!.path))
                                : userData?['userData']['profilePhoto'] != null
                                    ? NetworkImage(
                                        userData?['userData']['profilePhoto'])
                                    : AssetImage("assets/images/avatar_1.png")
                                        as ImageProvider,
                            radius: 48,
                          ),
                        ),
                        Positioned(
                            bottom: 0,
                            right: 0,
                            child: CustomIconButton(
                                onTap: _pickImage, icon: Icons.camera_alt)),
                      ],
                    ),
                    SizedBox(
                      height: 12,
                    ),
                    Text(
                      "Change Photo",
                      style: AppStyles.textStyle_15_600,
                    ),
                    SizedBox(
                      height: 32,
                    ),
                    CommentInputField(
                        commentController: _nameController,
                        title: "Name & Surname",
                        onChange: (value) {},
                        hintText: "",
                        height: 0.06),
                    SizedBox(
                      height: 22,
                    ),
                    CommentInputField(
                        commentController: _bioController,
                        title: "Bio",
                        onChange: (value) {},
                        hintText: ""),
                    SizedBox(
                      height: 32,
                    ),
                    CommentInputField(
                        commentController: _airlineController,
                        title: "Your Favorite Airline",
                        onChange: (value) {
                          _airlineController.text = value;
                        },
                        hintText: "",
                        height: 0.06),
                  ],
                ),
              ),
            ),
            bottomNavigationBar: BottomButtonBar(
                child: MainButton(
                    text: AppLocalizations.of(context).translate('Save'),
                    onPressed: () {
                      _editProfileFunction();
                    })),
          ),
        ),
        if (isLoading)
          Container(
              color: Colors.black.withAlpha(127), child: const LoadingWidget()),
      ],
    );
  }
}
