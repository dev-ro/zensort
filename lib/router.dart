import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:zensort/main.dart';
import 'package:zensort/legal/privacy_policy.dart';
import 'package:zensort/legal/terms_of_service.dart';
import 'package:zensort/legal/disclaimer.dart';

final GoRouter router = GoRouter(
  initialLocation: '/',
  routes: <GoRoute>[
    GoRoute(
      path: '/',
      builder: (BuildContext context, GoRouterState state) {
        return const LandingPage();
      },
    ),
    GoRoute(
      path: '/privacy',
      builder: (BuildContext context, GoRouterState state) {
        return const PrivacyPolicyPage();
      },
    ),
    GoRoute(
      path: '/terms',
      builder: (BuildContext context, GoRouterState state) {
        return const TermsOfServicePage();
      },
    ),
    GoRoute(
      path: '/disclaimer',
      builder: (BuildContext context, GoRouterState state) {
        return const DisclaimerPage();
      },
    ),
  ],
);
