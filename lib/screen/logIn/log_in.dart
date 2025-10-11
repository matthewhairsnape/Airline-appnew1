import 'dart:io';
import 'dart:ui';
import 'dart:convert';
import 'package:airline_app/provider/user_data_provider.dart';
import 'package:airline_app/screen/app_widgets/custom_snackbar.dart';
import 'package:airline_app/utils/app_routes.dart';
import 'package:airline_app/utils/app_styles.dart';
import 'package:airline_app/utils/global_variable.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
// import 'package:otpless_flutter/otpless_flutter.dart'; // Temporarily disabled
import 'package:http/http.dart' as http;
import 'package:airline_app/screen/app_widgets/loading.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shimmer/shimmer.dart';

class Login extends ConsumerStatefulWidget {
  const Login({super.key});

  @override
  ConsumerState<Login> createState() => _LoginState();
}

class _LoginState extends ConsumerState<Login> {
  // final _otplessFlutterPlugin = Otpless(); // Temporarily disabled
  List<Map<String, dynamic>> leaderBoardList = [];
  List<Map<String, dynamic>> reviewList = [];
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    // _otplessFlutterPlugin.enableDebugLogging(true); // Temporarily disabled
    _checkToken();
    // _initializeOtpless(); // Temporarily disabled
  }

  // Future<void> _initializeOtpless() async {
  //   if (Platform.isAndroid) {
  //     await _otplessFlutterPlugin.enableDebugLogging(true);
  //     await _otplessFlutterPlugin.initHeadless(appId);
  //     _otplessFlutterPlugin.setHeadlessCallback(onHeadlessResult);
  //   }
  //   _otplessFlutterPlugin.setWebviewInspectable(true);
  // } // Temporarily disabled

  Future<void> _checkToken() async {
    setState(() {
      isLoading = true;
    });

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    final lastAccessTime = prefs.getInt('lastAccessTime');
    final currentTime = DateTime.now().millisecondsSinceEpoch;

    // Check if 24 hours have passed since last access
    if (token != null &&
        lastAccessTime != null &&
        currentTime - lastAccessTime < Duration(hours: 24).inMilliseconds) {
      // Update last access time
      await prefs.setInt('lastAccessTime', currentTime);

      final userData = prefs.getString('userData');
      if (userData != null) {
        ref.read(userDataProvider.notifier).setUserData(json.decode(userData));
        if (mounted) {
          Navigator.pushNamed(context, AppRoutes.startreviews);
        }
      }
    } else {
      await prefs.clear();
    }
    setState(() {
      isLoading = false;
    });
  }

  // void onHeadlessResult(dynamic result) async {
  //   String jsonString = jsonEncode(result);
  //   final http.Response response;

  //   if (result != null && result['data'] != null) {
  //     showDialog(
  //       context: context,
  //       barrierDismissible: false,
  //       builder: (BuildContext context) {
  //         return Container(
  //           color: Colors.white.withAlpha(229),
  //           child: BackdropFilter(
  //             filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
  //             child: const Center(
  //               child: LoadingWidget(),
  //             ),
  //           ),
  //         );
  //       },
  //     );

  //     UserData userData = UserData.fromJson(jsonString);

  //     if (userData.channel == 'WHATSAPP') {
  //       response = await http.post(
  //         Uri.parse('$apiUrl/api/v1/user'),
  //         headers: <String, String>{
  //           'Content-Type': 'application/json; charset=UTF-8',
  //         },
  //         body: json.encode({
  //           'name': userData.name,
  //           'whatsappNumber': userData.identityValue,
  //           'email': "",
  //           'apple': "",
  //         }),
  //       );
  //     } else if (userData.channel == 'APPLE') {
  //       response = await http.post(
  //         Uri.parse('$apiUrl/api/v1/user'),
  //         headers: <String, String>{
  //           'Content-Type': 'application/json; charset=UTF-8',
  //         },
  //         body: json.encode({
  //           'name': userData.name,
  //           'whatsappNumber': "",
  //           'email': "",
  //           'apple': userData.identityValue,
  //         }),
  //       );
  //     } else {
  //       response = await http.post(
  //         Uri.parse('$apiUrl/api/v1/user'),
  //         headers: <String, String>{
  //           'Content-Type': 'application/json; charset=UTF-8',
  //         },
  //         body: json.encode({
  //           'name': userData.name,
  //           'whatsappNumber': '',
  //           'email': userData.identityValue,
  //           'apple': "",
  //         }),
  //       );
  //     }

  //     if (response.statusCode == 200) {
  //       final responseData = jsonDecode(response.body);
  //       ref.read(userDataProvider.notifier).setUserData(responseData);

  //       // When storing the data
  //       final prefs = await SharedPreferences.getInstance();
  //       final lastAccessTime = DateTime.now().millisecondsSinceEpoch;

  //       await prefs.setString('token', userData.idToken);
  //       await prefs.setString('userData', json.encode(responseData));
  //       await prefs.setInt('lastAccessTime', lastAccessTime);
  //       if (mounted) {
  //         Navigator.pop(context);
  //       }
  //       // Remove loading dialog

  //       if (responseData['userState'] == 0) {
  //         if (mounted) {
  //           Navigator.pushReplacementNamed(context, AppRoutes.skipscreen);
  //         }
  //       } else {
  //         if (mounted) {
  //           Navigator.pushReplacementNamed(
  //               context, AppRoutes.leaderboardscreen);
  //         }
  //       }
  //     } else {
  //       if (mounted) {
  //         Navigator.pop(context);
  //       }
  //     }
  //   } else {
  //     CustomSnackBar.error(context, 'Login failed. Please try again.');
  //   }
  // } // Temporarily disabled

  // Future<void> _openLoginPage() async {
  //   try {
  //     Map<String, dynamic> arg = {'appId': appId};
  //     await _otplessFlutterPlugin.openLoginPage(onHeadlessResult, arg);
  //   } catch (e) {
  //     if (!mounted) return;
  //     CustomSnackBar.error(context, 'WhatsApp login failed. Please try again.');
  //   }
  // } // Temporarily disabled

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          ShaderMask(
            shaderCallback: (bounds) {
              return LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withAlpha(76),
                  Colors.black.withAlpha(25)
                ],
              ).createShader(bounds);
            },
            blendMode: BlendMode.srcATop,
            child: Image.asset(
              'assets/images/pixar-background.png',
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity,
            ),
          ),
          Center(
            child: Padding(
              padding: const EdgeInsets.only(top: 120),
              child: Column(
                children: [
                  Container(
                      width: 160,
                      height: 160,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.white.withAlpha(76),
                            spreadRadius: 2,
                            blurRadius: 10,
                            offset: const Offset(0, 2),
                          ),
                        ],
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Colors.white.withAlpha(25),
                            Colors.white.withAlpha(13),
                          ],
                        ),
                      ),
                      padding: const EdgeInsets.fromLTRB(16, 24, 16, 10),
                      child: SvgPicture.asset(
                        'assets/icons/logo.svg',
                        width: 100,
                        height: 100,
                        colorFilter: ColorFilter.mode(
                          Colors.white.withAlpha(229),
                          BlendMode.srcIn,
                        ),
                      )),
                  Text(
                    "Exp.aero",
                    style: AppStyles.textStyle_24_600.copyWith(
                      letterSpacing: 1.5,
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(height: screenSize.height * 0.4),
                  Text(
                    "Let's get flying",
                    style: AppStyles.textStyle_40_700.copyWith(
                      letterSpacing: 1.2,
                      color: Colors.white,
                      shadows: [
                        Shadow(
                          color: Colors.black.withAlpha(153),
                          offset: const Offset(2, 3),
                          blurRadius: 5,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          isLoading
              ? const LoadingWidget()
              : Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Spacer(),
                      Padding(
                        padding: EdgeInsets.symmetric(
                            horizontal: screenSize.width * 0.1,
                            vertical: screenSize.height * 0.08),
                        child: Container(
                          width: double.infinity,
                          height: 56,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.white.withAlpha(229),
                                Colors.white.withAlpha(178),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(28),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withAlpha(51),
                                spreadRadius: 1,
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(28),
                              onTap: () {
                                Navigator.pushNamed(context, AppRoutes.startreviews);
                              },
                              child: Center(
                                child: Text(
                                  "Continue",
                                  style: AppStyles.textStyle_24_600.copyWith(
                                    color: Colors.black87,
                                    letterSpacing: 0.5,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
        ],
      ),
    );
  }
}

class UserData {
  final String name;
  final String identityValue;
  final String channel;
  final String idToken;

  UserData(
      {required this.name,
      required this.identityValue,
      required this.channel,
      required this.idToken});

  factory UserData.fromJson(String jsonString) {
    final Map<String, dynamic> json = jsonDecode(jsonString);
    final List<dynamic> identities = json['data']['identities'];

    if (identities.isEmpty) {
      throw Exception('No identities found in the JSON data');
    }

    final Map<String, dynamic> firstIdentity = identities.first;

    return UserData(
        name: firstIdentity['name'] ?? 'Unknown',
        identityValue: firstIdentity['identityValue'] ?? 'Unknown',
        channel: firstIdentity['channel'] ?? 'Unknown',
        idToken: json['data']['idToken'] ?? 'Unknown');
  }
}
