import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'theme/liquid_glass_theme.dart';
import 'providers/config_provider.dart';
import 'services/auto_backup_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await dotenv.load(fileName: ".env");
  } catch (e) {
    // Do nothing if .env file is not found
  }

  await Firebase.initializeApp();

  runApp(const ProviderScope(child: KardoApp()));
}

class KardoApp extends ConsumerStatefulWidget {
  const KardoApp({super.key});

  @override
  ConsumerState<KardoApp> createState() => _KardoAppState();
}

class _KardoAppState extends ConsumerState<KardoApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.resumed) {
      AutoBackupService.runIfNeeded();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = ref.watch(configProvider).isDark;

    return MaterialApp(
      title: 'Kardo Scan',
      debugShowCheckedModeBanner: false,
      theme: LiquidGlassTheme.lightTheme,
      darkTheme: LiquidGlassTheme.darkTheme,
      themeMode: isDark ? ThemeMode.dark : ThemeMode.light,
      // Status bar icons follow the active theme so the bar never
      // disappears into the scaffold behind it.
      builder: (context, child) => AnnotatedRegion<SystemUiOverlayStyle>(
        value: isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
        child: child ?? const SizedBox.shrink(),
      ),
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const _BrandedLoading();
          }
          if (snapshot.hasData && snapshot.data != null) {
            return const HomeScreen();
          }
          return const LoginScreen();
        },
      ),
    );
  }
}

/// Auth handshake screen — logo + wordmark on the themed scaffold, so the
/// native splash hands off without a jarring Material spinner.
class _BrandedLoading extends StatelessWidget {
  const _BrandedLoading();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              'assets/images/kardo_logo.png',
              width: 96,
              height: 96,
            ),
            const SizedBox(height: 24),
            Text(
              'Kardo Scan',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.4,
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 36),
            const CupertinoActivityIndicator(radius: 13),
          ],
        ),
      ),
    );
  }
}
