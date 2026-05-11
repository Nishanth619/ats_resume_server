import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'router/app_router.dart';
import 'theme/app_theme.dart';
import 'widgets/app_banner_ad.dart';
import '../providers/theme_provider.dart';

class ATSResumeApp extends ConsumerWidget {
  const ATSResumeApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final themeMode = ref.watch(themeModeProvider);
    return MaterialApp.router(
      title: 'ATS Resume Builder',
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
