import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'core/theme/app_theme.dart';
import 'core/utils/pwa_check.dart';
import 'features/home/home_screen.dart';
import 'features/install/install_prompt_page.dart';
import 'features/results/results_screen.dart';
import 'features/settings/gemini_api_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const HomeScreen(),
      ),
      GoRoute(
        path: '/results',
        builder: (context, state) => const ResultsScreen(),
      ),
      GoRoute(
        path: '/gemini-settings',
        builder: (context, state) => const GeminiApiScreen(),
      ),
      GoRoute(
        path: '/install',
        builder: (context, state) => const InstallPromptPage(),
      ),
    ],
  );
});

class KafaSayimiApp extends ConsumerStatefulWidget {
  const KafaSayimiApp({super.key});

  @override
  ConsumerState<KafaSayimiApp> createState() => _KafaSayimiAppState();
}

class _KafaSayimiAppState extends ConsumerState<KafaSayimiApp> {
  bool _dismissedInstallPrompt = false;

  @override
  Widget build(BuildContext context) {
    final isMobileWeb = kIsWeb && isMobileBrowser();
    if (isMobileWeb && !isPWA() && !_dismissedInstallPrompt) {
      return MaterialApp(
        title: 'Kafa Sayımı',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.darkTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: ThemeMode.dark,
        home: InstallPromptPage(
          onContinue: () {
            setState(() {
              _dismissedInstallPrompt = true;
            });
          },
        ),
      );
    }

    final router = ref.watch(routerProvider);
    return MaterialApp.router(
      title: 'Kafa Sayımı',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.dark,
      routerConfig: router,
    );
  }
}
