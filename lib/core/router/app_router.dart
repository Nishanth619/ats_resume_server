import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/onboarding/onboarding_screen.dart';
import '../../features/auth/login_screen.dart';
import '../../features/dashboard/dashboard_screen.dart';
import '../../features/template_picker/template_picker_screen.dart';
import '../../features/resume_editor/resume_editor_screen.dart';
import '../../features/preview/resume_preview_screen.dart';
import '../../features/preview/download_screen.dart';
import '../../features/job_tracker/job_tracker_screen.dart';
import '../../features/ats_checker/ats_score_screen.dart';
import '../../features/jd_matcher/jd_matcher_screen.dart';
import '../../features/cover_letter/cover_letter_screen.dart';
import '../../features/settings/settings_screen.dart';
import '../../providers/auth_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateProvider);

  return GoRouter(
    initialLocation: '/onboarding',
    redirect: (ctx, state) async {
      final prefs = await SharedPreferences.getInstance();
      final hasSeenOnboarding = prefs.getBool('has_seen_onboarding') ?? false;

      final isLoggedIn = authState.value != null;
      final isAuthRoute = state.uri.path == '/login' || state.uri.path == '/onboarding';

      if (!hasSeenOnboarding && state.uri.path != '/onboarding') {
        return '/onboarding';
      }

      if (!isLoggedIn && !isAuthRoute) return '/login';
      if (isLoggedIn && isAuthRoute) return '/dashboard';
      
      return null;
    },
    routes: [
      GoRoute(path: '/onboarding', builder: (_, __) => const OnboardingScreen()),
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
      GoRoute(path: '/dashboard', builder: (_, __) => const DashboardScreen()),
      GoRoute(path: '/templates', builder: (_, __) => const TemplatePickerScreen()),
      GoRoute(path: '/editor/:id', builder: (_, s) =>
          ResumeEditorScreen(
            resumeId: s.pathParameters['id']!,
            initialTemplate: s.uri.queryParameters['template'],
          )),
      GoRoute(path: '/ats/:id', builder: (_, s) =>
          ATSScoreScreen(resumeId: s.pathParameters['id']!)),
      GoRoute(path: '/jd/:id', builder: (_, s) =>
          JDMatcherScreen(resumeId: s.pathParameters['id']!)),
      GoRoute(path: '/cover-letter/:id', builder: (_, s) =>
          CoverLetterScreen(resumeId: s.pathParameters['id']!)),
      GoRoute(path: '/preview/:id', builder: (_, s) =>
          ResumePreviewScreen(resumeId: s.pathParameters['id']!)),
      GoRoute(path: '/download/:id', builder: (_, s) =>
          DownloadScreen(resumeId: s.pathParameters['id']!)),
      GoRoute(path: '/job-tracker', builder: (_, __) => const JobTrackerScreen()),
      GoRoute(path: '/settings', builder: (_, __) => const SettingsScreen()),
    ],
  );
});
