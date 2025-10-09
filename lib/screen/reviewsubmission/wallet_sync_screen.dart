import 'dart:io';
import 'package:airline_app/provider/user_data_provider.dart';
import 'package:airline_app/provider/flight_tracking_provider.dart';
import 'package:airline_app/screen/app_widgets/custom_snackbar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:airline_app/controller/boarding_pass_controller.dart';
import 'package:airline_app/controller/fetch_flight_info_by_cirium.dart';
import 'package:airline_app/models/boarding_pass.dart';
import 'package:airline_app/screen/app_widgets/loading.dart';
import 'package:airline_app/screen/app_widgets/main_button.dart';
import 'package:airline_app/screen/reviewsubmission/widgets/flight_confirmation_dialog.dart';
import 'package:airline_app/utils/app_styles.dart';

// Show the wallet sync dialog
void showWalletSyncDialog(BuildContext context) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    isDismissible: true,
    builder: (context) => const WalletSyncDialog(),
  );
}

enum WalletSyncStep { openWallet, chooseScreenshot }

class WalletSyncDialog extends ConsumerStatefulWidget {
  const WalletSyncDialog({super.key});

  @override
  ConsumerState<WalletSyncDialog> createState() => _WalletSyncDialogState();
}

class _WalletSyncDialogState extends ConsumerState<WalletSyncDialog> {
  final MobileScannerController _controller = MobileScannerController();
  final FetchFlightInforByCirium _flightInfoFetcher = FetchFlightInforByCirium();
  final BoardingPassController _boardingPassController = BoardingPassController();
  final ImagePicker _imagePicker = ImagePicker();

  Map<String, dynamic>? detailedBoardingPass;
  bool isLoading = false;
  WalletSyncStep currentStep = WalletSyncStep.openWallet;
  bool walletOpened = false;
  File? selectedImage;

  Future<void> parseIataBarcode(String rawValue) async {
    setState(() => isLoading = true);
    try {
      debugPrint("This is scanned barcode ========================> $rawValue");

      final RegExp regex = RegExp(
          r'([A-Z0-9]{5,7})\s+([A-Z]{6}[A-Z0-9]{2})\s+(\d{4})\s+(\d{3}[A-Z])');
      final Match? match = regex.firstMatch(rawValue);

      if (match == null) {
        throw Exception('Invalid barcode format');
      }

      final String pnr = match.group(1)!;
      final String routeOfFlight = match.group(2)!;
      final String flightNumber = match.group(3)!;
      final String julianDateAndClassOfService = match.group(4)!;
      final String departureAirport = routeOfFlight.substring(0, 3);
      final String carrier = routeOfFlight.substring(6, 8);
      final String julianDate = julianDateAndClassOfService.substring(0, 3);
      final String classOfServiceKey =
          julianDateAndClassOfService.substring(3, 4);
      final String classOfService = _getClassOfService(classOfServiceKey);
      final DateTime baseDate = DateTime(DateTime.now().year, 1, 0);
      final DateTime date = baseDate.add(Duration(days: int.parse(julianDate)));

      final bool pnrExists = await _boardingPassController.checkPnrExists(pnr);
      if (pnrExists) {
        if (mounted) {
          CustomSnackBar.info(
              context, "Boarding pass has already been reviewed.");
        }
        return;
      }

      Map<String, dynamic> flightInfo =
          await _flightInfoFetcher.fetchFlightInfo(
        carrier: carrier,
        flightNumber: flightNumber,
        flightDate: date,
        departureAirport: departureAirport,
      );

      if (flightInfo['flightStatuses']?.isEmpty ?? true) {
        final DateTime lastYearDate =
            DateTime(date.year - 1, date.month, date.day);
        flightInfo = await _flightInfoFetcher.fetchFlightInfo(
          carrier: carrier,
          flightNumber: flightNumber,
          flightDate: lastYearDate,
          departureAirport: departureAirport,
        );

        if (flightInfo['flightStatuses']?.isEmpty ?? true) {
          if (mounted) {
            CustomSnackBar.info(context,
                "Flight data is only available for up to one year in the past.");
          }
          return;
        }
      }

      await _processFetchedFlightInfo(flightInfo, pnr, classOfService);
    } catch (e) {
      if (mounted) {
        CustomSnackBar.info(context,
            "Oops! We had trouble processing your boarding pass. Please try again.");
      }
    } finally {
      setState(() => isLoading = false);
    }
  }

  String _getClassOfService(String key) {
    switch (key) {
      case "F":
        return "First";
      case "R":
        return "Premium Economy";
      case "J":
        return "Business";
      case "Y":
        return "Economy";
      default:
        return "Premium Economy";
    }
  }

  Future<void> _processFetchedFlightInfo(Map<String, dynamic> flightInfo,
      String pnr, String classOfService) async {
    if (flightInfo['flightStatuses']?.isEmpty ?? true) {
      CustomSnackBar.error(
          context, "No flight data found for the boarding pass.");
      return;
    }
    
    final flightStatus = flightInfo['flightStatuses'][0];
    final airlines = flightInfo['appendix']['airlines'];
    final airports = flightInfo['appendix']['airports'];
    final airlineName = airlines.firstWhere((airline) =>
        airline['fs'] == flightStatus['primaryCarrierFsCode'])['name'];
    final departureAirport = airports.firstWhere(
        (airport) => airport['fs'] == flightStatus['departureAirportFsCode']);
    final arrivalAirport = airports.firstWhere(
        (airport) => airport['fs'] == flightStatus['arrivalAirportFsCode']);
    final departureEntireTime =
        DateTime.parse(flightStatus['departureDate']['dateLocal']);
    final arrivalEntireTime =
        DateTime.parse(flightStatus['arrivalDate']['dateLocal']);

    // Get user ID, use empty string if not logged in
    final userId = ref.read(userDataProvider)?['userData']?['_id'] ?? '';

    final newPass = BoardingPass(
      name: userId.toString(),
      pnr: pnr,
      airlineName: airlineName ?? '',
      departureAirportCode: departureAirport['fs'] ?? '',
      departureCity: departureAirport['city'] ?? '',
      departureCountryCode: departureAirport['countryCode'] ?? '',
      departureTime: _formatTime(departureEntireTime),
      arrivalAirportCode: arrivalAirport['fs'] ?? '',
      arrivalCity: arrivalAirport['city'] ?? '',
      arrivalCountryCode: arrivalAirport['countryCode'] ?? '',
      arrivalTime: _formatTime(arrivalEntireTime),
      classOfTravel: classOfService,
      airlineCode: flightStatus['carrierFsCode'] ?? '',
      flightNumber:
          "${flightStatus['carrierFsCode']} ${flightStatus['flightNumber']}",
      visitStatus: _getVisitStatus(departureEntireTime),
    );

    final bool result = await _boardingPassController.saveBoardingPass(newPass);
    
    // Start real-time flight tracking with Cirium
    final carrier = flightStatus['carrierFsCode'] ?? '';
    final flightNumber = flightStatus['flightNumber']?.toString() ?? '';
    final flightDate = departureEntireTime;
    final departureAirportCode = departureAirport['fs'] ?? '';
    
    debugPrint('🪑 Starting flight tracking for wallet sync: $carrier $flightNumber');
    final trackingStarted = await ref.read(flightTrackingProvider.notifier).trackFlight(
      carrier: carrier,
      flightNumber: flightNumber,
      flightDate: flightDate,
      departureAirport: departureAirportCode,
      pnr: pnr,
      existingFlightData: flightInfo,
    );

    if (trackingStarted) {
      debugPrint('✈️ Flight tracking started successfully for $pnr');
    }
    
    if (mounted) {
      if (result) {
        CustomSnackBar.success(context, '✅ Boarding pass from wallet loaded successfully!');
      } else {
        CustomSnackBar.success(context, '✅ Flight loaded! Your journey is being tracked.');
      }
      
      // Close the wallet sync dialog
      Navigator.pop(context);
      
      // Show confirmation dialog
      FlightConfirmationDialog.show(
        context,
        newPass,
        onCancel: () {},
      );
    }
  }

  String _formatTime(DateTime time) =>
      "${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}";

  String _getVisitStatus(DateTime departureEntireTime) {
    final now = DateTime.now();
    final difference = now.difference(departureEntireTime);

    if (departureEntireTime.isAfter(now)) {
      return "Upcoming";
    } else if (difference.inDays <= 20) {
      return "Recent";
    } else {
      return "Earlier";
    }
  }

  Future<void> _launchWallet() async {
    if (kIsWeb) {
      throw 'Wallet launch is not supported on web platform';
    }

    final String url;
    final String fallbackUrl;

    if (Platform.isAndroid) {
      url = 'https://pay.google.com/gp/v/home';
      fallbackUrl =
          'https://play.google.com/store/apps/details?id=com.google.android.apps.walletnfcrel';
    } else if (Platform.isIOS) {
      url = 'shoebox://';
      fallbackUrl = 'https://apps.apple.com/us/app/wallet/id1160481993';
    } else {
      throw 'Unsupported platform for wallet launch';
    }

    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url));
    } else if (await canLaunchUrl(Uri.parse(fallbackUrl))) {
      await launchUrl(Uri.parse(fallbackUrl));
    } else {
      throw 'Could not launch wallet on ${Platform.operatingSystem}';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(24),
              topRight: Radius.circular(24),
            ),
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header with close button
              Row(
                children: [
                  Expanded(
                    child: Text(
                      "Sync from Your Wallet",
                      style: AppStyles.textStyle_24_600,
                      textAlign: TextAlign.center,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              
              // Progress Stepper
              _buildProgressStepper(),
              const SizedBox(height: 24),
              
              // Content based on current step
              _buildStepContent(),
              
              const SizedBox(height: 24),
              
              // Action buttons
              _buildActionButtons(),
            ],
          ),
        ),
        if (isLoading) const LoadingWidget(),
      ],
    );
  }

  Widget _buildProgressStepper() {
    return Row(
      children: [
        _buildStepDot(1, currentStep.index >= 0),
        _buildStepLine(currentStep.index >= 1),
        _buildStepDot(2, currentStep.index >= 1),
      ],
    );
  }

  Widget _buildStepDot(int stepNumber, bool isActive) {
    return Expanded(
      child: Container(
        height: 36,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isActive ? Colors.black : Colors.grey[300],
        ),
        child: Center(
          child: Text(
            stepNumber.toString(),
            style: AppStyles.textStyle_16_600.copyWith(
              color: isActive ? Colors.white : Colors.grey[600],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStepLine(bool isActive) {
    return Expanded(
      flex: 2,
      child: Container(
        height: 2,
        color: isActive ? Colors.black : Colors.grey[300],
      ),
    );
  }

  Widget _buildStepContent() {
    switch (currentStep) {
      case WalletSyncStep.openWallet:
        return _buildOpenWalletContent();
      case WalletSyncStep.chooseScreenshot:
        return _buildChooseScreenshotContent();
    }
  }

  Widget _buildOpenWalletContent() {
    return Column(
      children: [
        Icon(
          Icons.account_balance_wallet,
          size: 60,
          color: Colors.black,
        ),
        const SizedBox(height: 16),
        Text(
          "Step 1: Open Your Wallet",
          style: AppStyles.textStyle_20_600,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          "Open your wallet app and take a screenshot of your boarding pass",
          style: AppStyles.textStyle_14_500.copyWith(color: Colors.grey[700]),
          textAlign: TextAlign.center,
        ),
        if (walletOpened) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.green[50],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.green[300]!),
            ),
            child: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green[700], size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    "Wallet opened! Take your screenshot",
                    style: AppStyles.textStyle_14_600.copyWith(color: Colors.green[900]),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildChooseScreenshotContent() {
    return Column(
      children: [
        Icon(
          Icons.photo_library,
          size: 60,
          color: Colors.black,
        ),
        const SizedBox(height: 16),
        Text(
          "Step 2: Choose Screenshot",
          style: AppStyles.textStyle_20_600,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          selectedImage == null 
              ? "Select the boarding pass screenshot from your photos"
              : "Ready to verify! We'll scan the barcode and confirm your flight details",
          style: AppStyles.textStyle_14_500.copyWith(color: Colors.grey[700]),
          textAlign: TextAlign.center,
        ),
        if (selectedImage != null) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.green[50],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.green[300]!),
            ),
            child: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green[700], size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    "Screenshot selected - Click Verify to continue",
                    style: AppStyles.textStyle_14_600.copyWith(color: Colors.green[900]),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }


  Widget _buildActionButtons() {
    if (currentStep == WalletSyncStep.openWallet) {
      return Column(
        children: [
          MainButton(
            text: "Open Wallet App",
            onPressed: _handleOpenWallet,
            color: Colors.black,
            icon: const Icon(Icons.account_balance_wallet, color: Colors.white),
          ),
          if (walletOpened) ...[
            const SizedBox(height: 12),
            MainButton(
              text: "Continue to Next Step",
              onPressed: _moveToScreenshotStep,
              color: Colors.black,
            ),
          ],
          const SizedBox(height: 12),
          TextButton(
            onPressed: _moveToScreenshotStep,
            child: Text(
              "Already have a screenshot? Skip",
              style: AppStyles.textStyle_14_500.copyWith(
                color: Colors.grey[700],
                decoration: TextDecoration.underline,
              ),
            ),
          ),
        ],
      );
    } else if (currentStep == WalletSyncStep.chooseScreenshot) {
      return Column(
        children: [
          if (selectedImage == null) ...[
            MainButton(
              text: "Choose Screenshot",
              onPressed: _pickScreenshot,
              color: Colors.black,
              icon: const Icon(Icons.photo_library, color: Colors.white),
            ),
          ] else ...[
            MainButton(
              text: "Verify Boarding Pass",
              onPressed: _scanSelectedImage,
              color: Colors.black,
              icon: const Icon(Icons.check_circle, color: Colors.white),
            ),
          ],
          const SizedBox(height: 12),
          TextButton(
            onPressed: () {
              setState(() {
                currentStep = WalletSyncStep.openWallet;
                selectedImage = null;
              });
            },
            child: Text(
              "← Back",
              style: AppStyles.textStyle_14_500.copyWith(color: Colors.grey[700]),
            ),
          ),
        ],
      );
    } else {
      return const SizedBox.shrink();
    }
  }

  Future<void> _handleOpenWallet() async {
    try {
      await _launchWallet();
      setState(() {
        walletOpened = true;
      });
    } catch (e) {
      if (mounted) {
        CustomSnackBar.error(context, "Could not open wallet. Please try manually.");
      }
    }
  }

  void _moveToScreenshotStep() {
    setState(() {
      currentStep = WalletSyncStep.chooseScreenshot;
    });
  }

  Future<void> _pickScreenshot() async {
    try {
      final XFile? file = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 100,
      );
      
      if (file != null) {
        setState(() {
          selectedImage = File(file.path);
        });
      }
    } catch (e) {
      if (mounted) {
        CustomSnackBar.error(context, "Failed to pick image. Please try again.");
      }
    }
  }

  Future<void> _scanSelectedImage() async {
    if (selectedImage == null) return;
    
    setState(() => isLoading = true);

    try {
      final BarcodeCapture? barcodeCapture =
          await _controller.analyzeImage(selectedImage!.path);
      final String? rawValue = barcodeCapture?.barcodes.firstOrNull?.rawValue;
      
      if (rawValue != null) {
        await parseIataBarcode(rawValue);
      } else {
        if (mounted) {
          CustomSnackBar.error(context,
              "This boarding pass cannot be scanned due to poor quality.");
          setState(() {
            selectedImage = null;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        CustomSnackBar.info(context,
            'Unable to scan the boarding pass. Please try again with a clearer image.');
        setState(() {
          selectedImage = null;
        });
      }
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}
