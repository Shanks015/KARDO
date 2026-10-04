import 'package:flutter/material.dart';
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
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
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