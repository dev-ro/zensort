import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:zensort/screens/legal_screen.dart';
import 'package:zensort/auth_gate.dart';

final GoRouter router = GoRouter(
  initialLocation: '/',
  restorationScopeId: 'router',
  routes: <GoRoute>[
    GoRoute(
      path: '/',
      pageBuilder: (context, state) =>
          MaterialPage(key: state.pageKey, child: const AuthGate()),
      routes: [
        GoRoute(
          path: 'privacy',
          pageBuilder: (context, state) => MaterialPage(
            key: state.pageKey,
            child: const LegalScreen(docName: 'privacy_policy'),
          ),
        ),
        GoRoute(
          path: 'terms',
          pageBuilder: (context, state) => MaterialPage(
            key: state.pageKey,
            child: const LegalScreen(docName: 'terms_of_service'),
          ),
        ),
        GoRoute(
          path: 'disclaimer',
          pageBuilder: (context, state) => MaterialPage(
            key: state.pageKey,
            child: const LegalScreen(docName: 'disclaimer'),
          ),
        ),
      ],
    ),
  ],
);
