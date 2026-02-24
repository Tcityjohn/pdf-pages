import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/services/pdf_service.dart';
import 'core/services/usage_service.dart';
import 'core/services/analytics_service.dart';
import 'core/services/purchase_service.dart';
import 'core/services/recents_service.dart';
import 'core/widgets/shared_ui.dart';
import 'features/extractor/presentation/screens/page_grid_screen.dart';
import 'features/settings/presentation/screens/settings_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Supabase (for analytics)
  await Supabase.initialize(
    url: const String.fromEnvironment(
      'SUPABASE_URL',
      defaultValue: 'https://xofisqxcurigrcgegskq.supabase.co',
    ),
    anonKey: const String.fromEnvironment(
      'SUPABASE_ANON_KEY',
      defaultValue: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InhvZmlzcXhjdXJpZ3JjZ2Vnc2txIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzA2NjUzODYsImV4cCI6MjA4NjI0MTM4Nn0.eATyJ_Vb9N8sKdNuEB9OAx4A9P2wcgUsqvXbe3nDhX0',
    ),
  );

  await AnalyticsService.initialize();
  await PurchaseService.initialize();

  await SentryFlutter.init(
    (options) {
      options.dsn = 'https://41aa0c4b901fa8a4b0f705b63203e0c7@o4510670743011328.ingest.us.sentry.io/4510942454022144';
      options.environment = 'production';
      options.enableAutoPerformanceTracing = false;
      options.enableUserInteractionTracing = false;
      options.tracesSampleRate = 0;
    },
    appRunner: () => runApp(
      const ProviderScope(child: MyApp()),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PDF Pages',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.primary,
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: Colors.transparent,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
          foregroundColor: AppColors.textPrimary,
        ),
        useMaterial3: true,
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with WidgetsBindingObserver {
  final PdfService _pdfService = PdfService();
  final UsageService _usageService = UsageService();
  final RecentsService _recentsService = RecentsService();

  bool _isPickingFile = false;
  bool _usageServiceInitialized = false;
  int _remainingExtractions = 3;
  DateTime _lastPaused = DateTime.now();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeServices();

    // Track cold start
    AnalyticsService.trackEvent('app_opened', metadata: {'source': 'cold_start'});
    AnalyticsService.trackEvent('session_start');
    AnalyticsService.trackScreenViewed('home');
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _lastPaused = DateTime.now();
      AnalyticsService.trackEvent('session_end', metadata: {
        'duration_seconds': AnalyticsService.sessionDurationSeconds,
      });
      AnalyticsService.flush();
    } else if (state == AppLifecycleState.resumed) {
      final inactiveMinutes = DateTime.now().difference(_lastPaused).inMinutes;
      if (inactiveMinutes >= 30) {
        AnalyticsService.startNewSession();
        AnalyticsService.trackEvent('session_start');
      }
      AnalyticsService.trackEvent('app_opened', metadata: {'source': 'background'});
    }
  }

  Future<void> _initializeServices() async {
    try {
      await _usageService.initialize();
      await _recentsService.initialize();
      if (mounted) {
        final remaining = await _usageService.getRemainingExtractions();
        setState(() {
          _usageServiceInitialized = true;
          _remainingExtractions = remaining;
        });
      }
    } catch (e) {
      debugPrint('Error initializing services: $e');
      if (mounted) {
        setState(() {
          _usageServiceInitialized = true;
        });
      }
    }
  }

  /// Show error dialog for PDF loading errors
  Future<void> _showPdfErrorDialog(String message) async {
    AnalyticsService.trackErrorDisplayed(
      errorType: 'pdf_load_error',
      context: 'home',
    );
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cannot Open PDF'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _pickPdfFile(); // Try again with a different file
            },
            child: const Text('Try Another'),
          ),
        ],
      ),
    );
  }

  Future<void> _pickPdfFile() async {
    setState(() {
      _isPickingFile = true;
    });

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );

      if (result != null && result.files.single.path != null) {
        final filePath = result.files.single.path!;
        final fileName = result.files.single.name;

        await _openPdfFile(filePath, fileName);
      } else {
        setState(() {
          _isPickingFile = false;
        });
      }
    } catch (e) {
      setState(() {
        _isPickingFile = false;
      });
      if (mounted) {
        _showPdfErrorDialog('Error picking file: ${e.toString()}');
      }
    }
  }

  Future<void> _openPdfFile(String filePath, String fileName) async {
    setState(() {
      _isPickingFile = true;
    });

    try {
      final pageCount = await _pdfService.loadPdf(filePath);

      // Track PDF opened
      AnalyticsService.trackPdfOpened(pageCount: pageCount);

      // Add to recents
      await _recentsService.addRecent(fileName, filePath);

      setState(() {
        _isPickingFile = false;
      });

      if (mounted) {
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => PageGridScreen(
              pdfService: _pdfService,
              usageService: _usageService,
              recentsService: _recentsService,
              documentName: fileName,
              pageCount: pageCount,
            ),
          ),
        );

        // Refresh usage data when returning from page grid
        AnalyticsService.trackScreenViewed('home');
        if (_usageServiceInitialized) {
          final remaining = await _usageService.getRemainingExtractions();
          setState(() {
            _remainingExtractions = remaining;
          });
        }
      }
    } on PdfLoadException catch (e) {
      setState(() {
        _isPickingFile = false;
      });
      if (mounted) {
        _showPdfErrorDialog(e.toString());
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pdfService.closeDocument();
    AnalyticsService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GradientScaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings, color: Colors.white),
            onPressed: () {
              AnalyticsService.trackButtonTapped(buttonId: 'settings', screenName: 'home');
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const SettingsScreen(),
                ),
              );
            },
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32.0),
          child: Column(
            children: [
              const Spacer(flex: 2),

              // Typography hierarchy - Soft Minimal style
              Text(
                'Select a PDF',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: Colors.white.withValues(alpha: 0.85),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Extract Pages',
                style: TextStyle(
                  fontSize: 42,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -1,
                  color: Colors.white,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),

              // Subtitle
              Text(
                'Select specific pages from any PDF\nand save them as a new document',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.white.withValues(alpha: 0.8),
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),

              const Spacer(flex: 1),

              // Privacy badge - frosted glass style
              Container(
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.6),
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 12,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.lock_outline,
                      size: 14,
                      color: Colors.black.withValues(alpha: 0.75),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Documents never leave your device',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.black.withValues(alpha: 0.75),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Usage banner - frosted glass style
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.6),
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 12,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                child: Row(
                  children: [
                    // Usage dots - coral colored
                    Row(
                      children: [
                        for (int i = 0; i < 3; i++)
                          Padding(
                            padding: EdgeInsets.only(right: i < 2 ? 6 : 0),
                            child: Container(
                              width: 12,
                              height: 12,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: i < _remainingExtractions
                                    ? AppColors.primary
                                    : AppColors.primary.withValues(alpha: 0.3),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        '$_remainingExtractions free extractions left',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.black.withValues(alpha: 0.7),
                        ),
                      ),
                    ),
                    Icon(
                      Icons.chevron_right,
                      size: 18,
                      color: Colors.black.withValues(alpha: 0.5),
                    ),
                  ],
                ),
              ),

              const Spacer(flex: 1),

              // Black pill CTA button
              AppButton(
                label: _isPickingFile ? 'Opening...' : 'Select PDF',
                onPressed: _isPickingFile
                    ? null
                    : () {
                        AnalyticsService.trackButtonTapped(
                          buttonId: 'select_pdf',
                          screenName: 'home',
                        );
                        _pickPdfFile();
                      },
                isLoading: _isPickingFile,
              ),

              const Spacer(flex: 1),
            ],
          ),
        ),
      ),
    );
  }
}
