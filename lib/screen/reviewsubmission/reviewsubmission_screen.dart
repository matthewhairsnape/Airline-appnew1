import 'package:airline_app/controller/boarding_pass_controller.dart';
import 'package:airline_app/models/boarding_pass.dart';
import 'package:airline_app/provider/boarding_passes_provider.dart';
import 'package:airline_app/provider/user_data_provider.dart';
import 'package:airline_app/screen/app_widgets/appbar_widget.dart';
import 'package:airline_app/screen/app_widgets/bottom_button_bar.dart';
import 'package:airline_app/screen/app_widgets/loading.dart';
import 'package:airline_app/screen/reviewsubmission/google_calendar/google_calendar_screen.dart';
import 'package:airline_app/screen/reviewsubmission/scanner_screen/scanner_screen.dart';
import 'package:airline_app/screen/reviewsubmission/wallet_sync_screen.dart';
import 'package:airline_app/screen/app_widgets/main_button.dart';
import 'package:airline_app/screen/reviewsubmission/widgets/review_flight_card.dart';
import 'package:airline_app/utils/app_localizations.dart';
import 'package:airline_app/utils/app_routes.dart';
import 'package:airline_app/utils/app_styles.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ReviewsubmissionScreen extends ConsumerStatefulWidget {
  const ReviewsubmissionScreen({super.key});

  @override
  ConsumerState<ReviewsubmissionScreen> createState() =>
      _ReviewsubmissionScreenState();
}

class _ReviewsubmissionScreenState
    extends ConsumerState<ReviewsubmissionScreen> {
  bool isLoading = true;

  final _boardingPassController = BoardingPassController();

  @override
  void initState() {
    super.initState();
    // Delay provider modification until after widget tree is built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  Future<void> _loadData() async {
    try {
      final userId = ref.read(userDataProvider)?['userData']['_id'];
      // Only fetch boarding passes if user is logged in
      if (userId != null && userId.toString().isNotEmpty) {
        final boardingPasses = await _boardingPassController
            .getBoardingPasses(userId.toString());
        if (mounted) {
          ref.read(boardingPassesProvider.notifier).setData(boardingPasses);
        }
      } else {
        // User not logged in, set empty list
        if (mounted) {
          ref.read(boardingPassesProvider.notifier).setData([]);
        }
      }
    } catch (e) {
      debugPrint('Error loading data: $e');
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  Widget _buildEmptyState() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const SizedBox(height: 24),
      Text(
        AppLocalizations.of(context).translate('Nothing to show here'),
        style: AppStyles.textStyle_24_600,
      ),
      Text(
          AppLocalizations.of(context).translate(
              'Here, you can synchronize your calendar and wallet or manually input the review details.'),
          style: AppStyles.textStyle_15_500
              .copyWith(color: const Color(0xff38433E))),
    ]);
  }

  Widget _buildCardWidget(BoardingPass singleBoardingPass) {
    final index = ref.watch(boardingPassesProvider).indexOf(singleBoardingPass);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0),
      child: Column(
        children: [
          ReviewFlightCard(
            singleBoardingPass: singleBoardingPass,
            index: index,
            isReviewed: singleBoardingPass.isReviewed,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final List<BoardingPass> boardingPasses = ref.watch(boardingPassesProvider);
    return PopScope(
      canPop: false, // Prevents the default pop action
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          Navigator.pushNamed(context, AppRoutes.startreviews);
        }
      },
      child: Scaffold(
        appBar: AppbarWidget(
          title: "Connect",
          onBackPressed: () {
            Navigator.pushNamed(context, AppRoutes.startreviews);
          },
        ),
        body: isLoading
            ? const Center(child: LoadingWidget())
            : Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: boardingPasses.isEmpty
                    ? _buildEmptyState()
                    : ListView(
                        children: [
                          // _buildTypeSelector(),
                          const SizedBox(height: 24),
                          ...boardingPasses.map(_buildCardWidget),
                        ],
                      ),
              ),
        bottomNavigationBar: BottomButtonBar(
          child: MainButton(
            text: AppLocalizations.of(context).translate('Next'),
            color: const Color(0xFF000000),
            onPressed: () {
              showModalBottomSheet(
                context: context,
                backgroundColor: Colors.white,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                ),
                builder: (BuildContext context) {
                  return SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 32, vertical: 28),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            AppLocalizations.of(context).translate('Choose Sync Option'),
                            style: AppStyles.textStyle_24_600,
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 24),
                          MainButton(
                            text: AppLocalizations.of(context)
                                .translate('Sync from Your Wallet'),
                            onPressed: () {
                              Navigator.pop(context);
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (context) =>
                                      const WalletSyncScreen(),
                                ),
                              );
                            },
                            icon: const Icon(Icons.account_balance_wallet, color: Colors.white),
                          ),
                          const SizedBox(height: 12),
                          MainButton(
                            text: AppLocalizations.of(context)
                                .translate('Sync from Google Calendar'),
                            onPressed: () {
                              Navigator.pop(context);
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (context) =>
                                      GoogleCalendarScreen(),
                                ),
                              );
                            },
                            icon: const Icon(Icons.calendar_today, color: Colors.white),
                          ),
                          const SizedBox(height: 12),
                          MainButton(
                            text: AppLocalizations.of(context)
                                .translate('Scan your boarding pass'),
                            onPressed: () {
                              Navigator.pop(context);
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (context) => ScannerScreen(),
                                ),
                              );
                            },
                            icon: const Icon(Icons.qr_code_scanner, color: Colors.white),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );            },
          ),
        ),
      ),
    );
  }
}
