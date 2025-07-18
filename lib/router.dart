import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:zensort/main.dart';
import 'package:zensort/legal/privacy_policy.dart';
import 'package:zensort/legal/terms_of_service.dart';
import 'package:zensort/legal/disclaimer.dart';

final GoRouter router = GoRouter(
  initialLocation: '/',
  restorationScopeId: 'router',
  routes: <GoRoute>[
    GoRoute(
      path: '/',
      pageBuilder: (context, state) =>
          MaterialPage(key: state.pageKey, child: const LandingPage()),
      routes: [
        GoRoute(
          path: 'privacy',
          pageBuilder: (context, state) => MaterialPage(
            key: state.pageKey,
            child: const PrivacyPolicyPage(),
          ),
        ),
        GoRoute(
          path: 'terms',
          pageBuilder: (context, state) => MaterialPage(
            key: state.pageKey,
            child: const TermsOfServicePage(),
          ),
        ),
        GoRoute(
          path: 'disclaimer',
          pageBuilder: (context, state) =>
              MaterialPage(key: state.pageKey, child: const DisclaimerPage()),
        ),
      ],
    ),
  ],
);
