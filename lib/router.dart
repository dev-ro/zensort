import 'package:go_router/go_router.dart';
import 'package:zensort/features/auth/presentation/auth_gate.dart';
import 'package:zensort/features/youtube/presentation/screens/home_screen.dart';
import 'package:zensort/screens/legal_screen.dart';
import 'package:zensort/screens/splash_screen.dart';
import 'package:zensort/screens/sync_progress_screen.dart';

final GoRouter router = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(path: '/', builder: (context, state) => const AuthGate()),
    GoRoute(path: '/home', builder: (context, state) => const HomeScreen()),
    GoRoute(path: '/splash', builder: (context, state) => const SplashScreen()),
    GoRoute(
      path: '/legal/:page',
      builder: (context, state) {
        final page = state.pathParameters['page']!;
        return LegalScreen(docName: page);
      },
    ),
    GoRoute(
      path: '/sync',
      builder: (context, state) => const SyncProgressScreen(),
    ),
  ],
);