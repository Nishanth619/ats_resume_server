import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../router/app_router.dart';
import '../theme/app_theme.dart';
import '../widgets/app_banner_ad.dart';
import '../../providers/theme_provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/subscription_service.dart';

class ATSResumeApp extends ConsumerStatefulWidget {
  const ATSResumeApp({super.key});

  @override
  ConsumerState<ATSResumeApp> createState() => _ATSResumeAppState();
}

class _ATSResumeAppState extends ConsumerState<ATSResumeApp> {
  @override
  void initState() {
    super.initState();
    // Listen to Firestore user document changes and sync subscription state.
    // This runs once when the widget first mounts; the ref.listen handles
    // subsequent changes reactively.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _syncSubscriptionFromUserData();
    });
  }

  void _syncSubscriptionFromUserData() {
    ref.listenManual(userDataProvider, (prev, next) {
      next.whenData((user) {
        if (user != null) {
          ref
              .read(subscriptionProvider.notifier)
              .setFromUserModel(user.plan);
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);
    final themeMode = ref.watch(themeModeProvider);
    return MaterialApp.router(
      title: 'Ats.Ai',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      routerConfig: router,
      builder: (context, child) {
        return Column(
          children: [
            Expanded(child: child ?? const SizedBox.shrink()),
            Material(
              color: Theme.of(context).colorScheme.surface,
              child: const Center(child: AppBannerAd()),
            ),
          ],
        );
      },
      debugShowCheckedModeBanner: false,
    );
  }
}
