import 'dart:async';
import 'dart:convert';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/app_export.dart';
import '../../core/services/app_data_service.dart';
import '../../core/services/gemini_triage_service.dart';
import '../../core/services/location_service.dart';
import '../../core/services/notification_service.dart';
import '../../widgets/notification_panel_widget.dart';
import '../rankings_screen/rankings_screen.dart';
import './widgets/ai_result_card_widget.dart';
import './widgets/camera_capture_widget.dart';
import './widgets/karma_header_widget.dart';
import './widgets/my_reports_list_widget.dart';

class CitizenReportingScreen extends StatefulWidget {
  const CitizenReportingScreen({super.key});

  @override
  State<CitizenReportingScreen> createState() => _CitizenReportingScreenState();
}

class _CitizenReportingScreenState extends State<CitizenReportingScreen>
    with TickerProviderStateMixin {
  Map<String, dynamic>? _currentUser;

  Map<String, dynamic>? _aiTriageResult;
  bool _isAnalyzing = false;
  bool _hasCapture = false;
  String? _capturedImageBase64;
  double _currentLat = LocationService.defaultLat;
  double _currentLng = LocationService.defaultLng;
  bool _showNotifications = false;
  StreamSubscription<AppNotification>? _notifSub;
  bool _showApiKeyBanner = false;
  String? _lastAnalysisError;

  // Bottom nav: 0=My Reports, 1=Camera, 2=Rankings
  int _bottomNavIndex = 0;

  @override
  void initState() {
    super.initState();
    _fetchLocation();

    _notifSub = NotificationService.instance.notificationStream.listen((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final extra = GoRouterState.of(context).extra;
    if (extra is Map<String, dynamic>) {
      _currentUser = extra;
    } else {
      _currentUser =
          AppDataService.instance.getUserById(1) ??
          {
            'id': 1,
            'name': 'Maya Patel',
            'role': 'CITIZEN',
            'karma': 145,
            'email': 'citizen@civic.local',
          };
    }
  }

  @override
  void dispose() {
    _notifSub?.cancel();
    super.dispose();
  }

  int get _unreadCount => NotificationService.instance.getUnreadCount(
    _currentUser?['id'] as int? ?? 1,
  );

  Future<void> _fetchLocation() async {
    final loc = await LocationService.getCurrentLocation();
    if (mounted) {
      setState(() {
        _currentLat = loc['latitude']!;
        _currentLng = loc['longitude']!;
      });
    }
  }

  Future<void> _onPhotoCapture() async {
    final picker = ImagePicker();
    try {
      final XFile? image = await picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 70,
        maxWidth: 1024,
        maxHeight: 1024,
      );

      if (image == null) return;

      final bytes = await image.readAsBytes();
      final base64Str = base64Encode(bytes);

      setState(() {
        _isAnalyzing = true;
        _hasCapture = true;
        _aiTriageResult = null;
        _capturedImageBase64 = base64Str;
        _showApiKeyBanner = false;
        _lastAnalysisError = null;
        // Switch to camera/report tab
        _bottomNavIndex = 1;
      });

      final loc = await LocationService.getCurrentLocation();
      _currentLat = loc['latitude']!;
      _currentLng = loc['longitude']!;

      final result = await GeminiTriageService.triageImage(
        base64Image: base64Str,
        latitude: _currentLat,
        longitude: _currentLng,
        existingTickets: AppDataService.instance.tickets,
      );

      if (!mounted) return;

      final apiKeyMissing = result['apiKeyMissing'] == true;
      final errorMsg = result['error'] as String?;
      final hasValidResult =
          !apiKeyMissing &&
          result['category'] != null &&
          result['category'] != 'Unknown' &&
          (result['confidence'] as num? ?? 0) > 0;

      setState(() {
        _isAnalyzing = false;
        _showApiKeyBanner = apiKeyMissing;
        if (hasValidResult) {
          _aiTriageResult = result;
          _lastAnalysisError = null;
        } else {
          _aiTriageResult = null;
          _lastAnalysisError = errorMsg;
          if (apiKeyMissing) _hasCapture = false;
        }
      });

      if (apiKeyMissing) {
        _showApiKeyDialog(errorMsg: errorMsg);
      } else if (errorMsg != null &&
          result['category'] == 'Road Hazard' &&
          result['confidence'] == 0.0) {
        // Real error occurred — show specific error message as toast
        setState(() {
          _hasCapture = false;
          _aiTriageResult = null;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                errorMsg,
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
              backgroundColor: AppTheme.error,
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              margin: const EdgeInsets.all(16),
              action: SnackBarAction(
                label: 'Set API Key',
                textColor: Colors.white,
                onPressed: () => _showApiKeyDialog(errorMsg: errorMsg),
              ),
            ),
          );
        }
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isAnalyzing = false;
        _hasCapture = false;
        _showApiKeyBanner = false;
        _lastAnalysisError = e.toString();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Error: ${e.toString()}',
            style: GoogleFonts.plusJakartaSans(fontSize: 12),
          ),
          backgroundColor: AppTheme.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          margin: const EdgeInsets.all(16),
        ),
      );
    }
  }

  void _showApiKeyDialog({String? errorMsg}) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppTheme.primary.withAlpha(38),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Center(
                child: CustomIconWidget(
                  iconName: 'key',
                  color: AppTheme.primary,
                  size: 18,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Gemini API Key Required',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (errorMsg != null) ...[
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.error.withAlpha(30),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.error.withAlpha(80)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const CustomIconWidget(
                      iconName: 'error_outline',
                      color: AppTheme.error,
                      size: 14,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        errorMsg,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11,
                          color: const Color(0xFFFC8181),
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],
            Text(
              'AI image analysis requires a valid Google Gemini API key. Paste your key below to enable live hazard detection.',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                color: const Color(0xFF94A3B8),
                height: 1.5,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                color: Colors.white,
              ),
              decoration: InputDecoration(
                hintText: 'AIza...',
                hintStyle: GoogleFonts.plusJakartaSans(
                  color: const Color(0xFF475569),
                  fontSize: 13,
                ),
                filled: true,
                fillColor: Colors.white.withAlpha(10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: Colors.white.withAlpha(30),
                    width: 1,
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: Colors.white.withAlpha(30),
                    width: 1,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                    color: AppTheme.primary,
                    width: 1.5,
                  ),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                suffixIcon: IconButton(
                  icon: const CustomIconWidget(
                    iconName: 'content_paste',
                    color: Color(0xFF64748B),
                    size: 16,
                  ),
                  onPressed: () async {
                    final data = await Clipboard.getData('text/plain');
                    if (data?.text != null) {
                      controller.text = data!.text!.trim();
                    }
                  },
                ),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Get your free API key at aistudio.google.com',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 11,
                color: AppTheme.primary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              setState(() => _showApiKeyBanner = false);
            },
            child: Text(
              'Cancel',
              style: GoogleFonts.plusJakartaSans(
                color: const Color(0xFF64748B),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              final key = controller.text.trim();
              if (key.isEmpty) return;
              // Save key to runtime so it takes effect immediately
              GeminiTriageService.setRuntimeApiKey(key);
              Navigator.of(ctx).pop();
              setState(() {
                _showApiKeyBanner = false;
                _lastAnalysisError = null;
              });
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'API key saved! Retrying analysis...',
                    style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                  backgroundColor: AppTheme.success,
                  behavior: SnackBarBehavior.floating,
                  duration: const Duration(seconds: 3),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  margin: const EdgeInsets.all(16),
                ),
              );
              // Retry analysis with the saved key
              if (_capturedImageBase64 != null) {
                setState(() {
                  _isAnalyzing = true;
                  _hasCapture = true;
                  _aiTriageResult = null;
                });
                final result = await GeminiTriageService.triageImage(
                  base64Image: _capturedImageBase64!,
                  latitude: _currentLat,
                  longitude: _currentLng,
                  existingTickets: AppDataService.instance.tickets,
                );
                if (!mounted) return;
                final retryError = result['error'] as String?;
                final retryKeyMissing = result['apiKeyMissing'] == true;
                setState(() {
                  _isAnalyzing = false;
                  if (!retryKeyMissing &&
                      result['category'] != null &&
                      result['category'] != 'Unknown') {
                    _aiTriageResult = result;
                    _lastAnalysisError = null;
                  } else {
                    _hasCapture = false;
                    _aiTriageResult = null;
                    _lastAnalysisError = retryError;
                    _showApiKeyBanner = retryKeyMissing;
                  }
                });
                if (retryError != null && mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Retry failed: $retryError',
                        style: GoogleFonts.plusJakartaSans(fontSize: 12),
                      ),
                      backgroundColor: AppTheme.error,
                      behavior: SnackBarBehavior.floating,
                      duration: const Duration(seconds: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      margin: const EdgeInsets.all(16),
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            ),
            child: Text(
              'Save & Retry',
              style: GoogleFonts.plusJakartaSans(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _onSubmitReport() async {
    if (_aiTriageResult == null) return;

    final isDuplicate = _aiTriageResult!['isDuplicate'] == true;
    final duplicateId = _aiTriageResult!['duplicateTicketId'] as String?;

    if (isDuplicate && duplicateId != null) {
      await AppDataService.instance.upvoteTicket(duplicateId);
      final userId = _currentUser?['id'] as int?;
      if (userId != null) {
        await AppDataService.instance.updateUserKarma(userId, 5);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Duplicate detected! Upvoted ticket $duplicateId. +5 Karma Points awarded.',
              style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600),
            ),
            backgroundColor: AppTheme.warning,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            margin: const EdgeInsets.all(16),
          ),
        );
      }
    } else {
      final userId = _currentUser?['id'] as int? ?? 1;
      final newTicket = await AppDataService.instance.addTicket({
        'category': _aiTriageResult!['category'],
        'severity': _aiTriageResult!['severity'],
        'aiReason': _aiTriageResult!['reason'],
        'aiCategory': _aiTriageResult!['category'],
        'latitude': _currentLat,
        'longitude': _currentLng,
        'address': LocationService.formatCoordinates(_currentLat, _currentLng),
        'timestamp': DateTime.now().toIso8601String(),
        'assignedTo': null,
        'reporter': _currentUser?['name'] ?? 'Citizen',
        'userId': userId,
        'imageBase64': _capturedImageBase64,
        'karmaAwarded': false,
      });

      // Award 10 karma for new report
      await AppDataService.instance.updateUserKarma(userId, 10);

      // Notify all admins of new report
      final admins = AppDataService.instance.getAdmins();
      for (final admin in admins) {
        NotificationService.instance.notifyAdminNewReport(
          adminUserId: admin['id'] as int,
          ticketId: newTicket['id'] as String,
          category: _aiTriageResult!['category'] as String,
          severity: _aiTriageResult!['severity'] as String,
          reporterName: _currentUser?['name'] as String? ?? 'Citizen',
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Report ${newTicket['id']} submitted! +10 Karma Points awarded.',
              style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600),
            ),
            backgroundColor: AppTheme.success,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            margin: const EdgeInsets.all(16),
          ),
        );
      }
    }

    final updatedUser = AppDataService.instance.getUserById(
      _currentUser?['id'] as int? ?? 1,
    );

    setState(() {
      _hasCapture = false;
      _aiTriageResult = null;
      _capturedImageBase64 = null;
      if (updatedUser != null) _currentUser = updatedUser;
      // Go to My Reports after submission
      _bottomNavIndex = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                _buildAppBar(context),
                Expanded(child: _buildBody()),
              ],
            ),
            if (_showNotifications)
              Positioned(
                top: 60,
                right: 16,
                left: 16,
                child: NotificationPanelWidget(
                  userId: _currentUser?['id'] as int? ?? 1,
                  onClose: () => setState(() => _showNotifications = false),
                ),
              ),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomNavBar(),
    );
  }

  Widget _buildBody() {
    switch (_bottomNavIndex) {
      case 0:
        return MyReportsListWidget(
          userId: _currentUser?['id'] as int? ?? 1,
          currentUser: _currentUser,
        );
      case 1:
        return _buildCameraReportTab();
      case 2:
        return RankingsScreen(currentUser: _currentUser);
      default:
        return MyReportsListWidget(
          userId: _currentUser?['id'] as int? ?? 1,
          currentUser: _currentUser,
        );
    }
  }

  Widget _buildBottomNavBar() {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.backgroundDark,
        border: Border(
          top: BorderSide(color: Colors.white.withAlpha(20), width: 1),
        ),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 64,
          child: Row(
            children: [
              // My Reports
              Expanded(
                child: _buildNavItem(
                  index: 0,
                  iconName: 'receipt_long',
                  label: 'My Reports',
                ),
              ),
              // Camera (center, prominent)
              GestureDetector(
                onTap: _onPhotoCapture,
                child: Container(
                  width: 60,
                  height: 60,
                  margin: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppTheme.primary, AppTheme.secondary],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.primary.withAlpha(100),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Center(
                    child: CustomIconWidget(
                      iconName: 'camera_alt',
                      color: Colors.white,
                      size: 26,
                    ),
                  ),
                ),
              ),
              // Rankings
              Expanded(
                child: _buildNavItem(
                  index: 2,
                  iconName: 'emoji_events',
                  label: 'Rankings',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required int index,
    required String iconName,
    required String label,
  }) {
    final isSelected = _bottomNavIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _bottomNavIndex = index),
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CustomIconWidget(
            iconName: iconName,
            color: isSelected ? AppTheme.primary : const Color(0xFF64748B),
            size: 22,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 10,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              color: isSelected ? AppTheme.primary : const Color(0xFF64748B),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCameraReportTab() {
    final isTablet = MediaQuery.of(context).size.width >= 600;
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 12),
          _buildGpsIndicator(),
          const SizedBox(height: 16),
          if (_showApiKeyBanner) ...[
            _buildApiKeyBanner(),
            const SizedBox(height: 16),
          ],
          // Show captured photo if available
          if (_hasCapture && _capturedImageBase64 != null) ...[
            _buildCapturedPhotoPreview(),
            const SizedBox(height: 16),
          ],
          if (!_hasCapture)
            CameraCaptureWidget(
              hasCapture: _hasCapture,
              isAnalyzing: _isAnalyzing,
              onCapture: _onPhotoCapture,
            ),
          if (_hasCapture) ...[
            AiResultCardWidget(
              isLoading: _isAnalyzing,
              result: _aiTriageResult,
            ),
          ],
          if (_aiTriageResult != null &&
              _aiTriageResult!['isDuplicate'] == true) ...[
            const SizedBox(height: 12),
            _buildDuplicateBanner(),
          ],
          if (_aiTriageResult != null) ...[
            const SizedBox(height: 16),
            _buildSubmitButton(),
          ],
          if (_hasCapture && !_isAnalyzing) ...[
            const SizedBox(height: 12),
            _buildRetakeButton(),
          ],
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildCapturedPhotoPreview() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: double.infinity,
        constraints: const BoxConstraints(maxHeight: 220),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.primary.withAlpha(60), width: 1),
        ),
        child: Stack(
          children: [
            Image.memory(
              base64Decode(_capturedImageBase64!),
              width: double.infinity,
              fit: BoxFit.cover,
              semanticLabel: 'Captured civic hazard photo',
            ),
            Positioned(
              top: 8,
              left: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black.withAlpha(160),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CustomIconWidget(
                      iconName: 'camera_alt',
                      color: Colors.white,
                      size: 12,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Captured Photo',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (_isAnalyzing)
              Positioned.fill(
                child: Container(
                  color: Colors.black.withAlpha(100),
                  child: const Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(
                        AppTheme.primary,
                      ),
                      strokeWidth: 2.5,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildRetakeButton() {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: () {
          setState(() {
            _hasCapture = false;
            _aiTriageResult = null;
            _capturedImageBase64 = null;
            _lastAnalysisError = null;
          });
        },
        icon: const CustomIconWidget(
          iconName: 'camera_alt',
          color: Color(0xFF94A3B8),
          size: 16,
        ),
        label: Text(
          'Retake Photo',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF94A3B8),
          ),
        ),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 12),
          side: BorderSide(color: Colors.white.withAlpha(40), width: 1),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

  Widget _buildApiKeyBanner() {
    return GestureDetector(
      onTap: _showApiKeyDialog,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.error.withAlpha(20),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppTheme.error.withAlpha(80), width: 1),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppTheme.error.withAlpha(30),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Center(
                child: CustomIconWidget(
                  iconName: 'key_off',
                  color: AppTheme.error,
                  size: 18,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Gemini API Key Missing',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.error,
                    ),
                  ),
                  Text(
                    'Tap to enter your API key and enable live AI hazard analysis.',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      color: const Color(0xFF94A3B8),
                    ),
                  ),
                ],
              ),
            ),
            const CustomIconWidget(
              iconName: 'chevron_right',
              color: AppTheme.error,
              size: 18,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGpsIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(8),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withAlpha(20), width: 1),
      ),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              color: AppTheme.success,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          const CustomIconWidget(
            iconName: 'gps_fixed',
            color: AppTheme.success,
            size: 14,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              LocationService.formatCoordinates(_currentLat, _currentLng),
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                color: const Color(0xFF94A3B8),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          GestureDetector(
            onTap: _fetchLocation,
            child: const CustomIconWidget(
              iconName: 'refresh_rounded',
              color: Color(0xFF64748B),
              size: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDuplicateBanner() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.warning.withAlpha(20),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.warning.withAlpha(64), width: 1),
      ),
      child: Row(
        children: [
          const CustomIconWidget(
            iconName: 'info_outline',
            color: AppTheme.warning,
            size: 16,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Duplicate Detected',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.warning,
                  ),
                ),
                Text(
                  'A similar hazard of the same type exists within 30m. Submitting will upvote the existing ticket and award +5 Karma.',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    color: const Color(0xFF94A3B8),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      child: GestureDetector(
        onTap: _onSubmitReport,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppTheme.primary, AppTheme.secondary],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: AppTheme.primary.withAlpha(77),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Center(
            child: Text(
              _aiTriageResult?['isDuplicate'] == true
                  ? 'Upvote Existing Report (+5 Karma)'
                  : 'Submit Report (+10 Karma)',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAppBar(BuildContext context) {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          decoration: BoxDecoration(
            color: AppTheme.backgroundDark.withAlpha(179),
            border: Border(
              bottom: BorderSide(color: Colors.white.withAlpha(20), width: 1),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppTheme.primary, AppTheme.secondary],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Center(
                  child: CustomIconWidget(
                    iconName: 'location_city',
                    color: Colors.white,
                    size: 18,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'CivicPulse AI',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      'Citizen Hub',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        color: const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
              KarmaHeaderWidget(karma: _currentUser?['karma'] as int? ?? 0),
              const SizedBox(width: 8),
              // API Key settings button
              GestureDetector(
                onTap: () => _showApiKeyDialog(),
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: GeminiTriageService.isApiKeyConfigured
                        ? Colors.white.withAlpha(15)
                        : AppTheme.error.withAlpha(40),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: GeminiTriageService.isApiKeyConfigured
                          ? Colors.white.withAlpha(26)
                          : AppTheme.error.withAlpha(120),
                      width: 1,
                    ),
                  ),
                  child: Center(
                    child: Text('⚙️', style: const TextStyle(fontSize: 16)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Notification bell
              GestureDetector(
                onTap: () =>
                    setState(() => _showNotifications = !_showNotifications),
                child: Stack(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: _showNotifications
                            ? AppTheme.primary.withAlpha(30)
                            : Colors.white.withAlpha(15),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: _showNotifications
                              ? AppTheme.primary.withAlpha(80)
                              : Colors.white.withAlpha(26),
                          width: 1,
                        ),
                      ),
                      child: Center(
                        child: CustomIconWidget(
                          iconName: 'notifications_outlined',
                          color: _showNotifications
                              ? AppTheme.primary
                              : const Color(0xFF94A3B8),
                          size: 18,
                        ),
                      ),
                    ),
                    if (_unreadCount > 0)
                      Positioned(
                        top: 4,
                        right: 4,
                        child: Container(
                          width: 14,
                          height: 14,
                          decoration: const BoxDecoration(
                            color: AppTheme.success,
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text(
                              _unreadCount > 9 ? '9+' : '$_unreadCount',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 8,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              InkWell(
                onTap: () => context.go(AppRoutes.loginScreen),
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(15),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: Colors.white.withAlpha(26),
                      width: 1,
                    ),
                  ),
                  child: const Center(
                    child: CustomIconWidget(
                      iconName: 'logout',
                      color: Color(0xFF94A3B8),
                      size: 18,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
