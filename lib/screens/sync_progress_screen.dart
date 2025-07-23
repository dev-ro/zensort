import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:zensort/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:zensort/widgets/zen_sort_scaffold.dart';
import 'package:zensort/widgets/gradient_loader.dart';
import 'package:zensort/widgets/animated_gradient_app_bar.dart';

class SyncProgressScreen extends StatefulWidget {
  const SyncProgressScreen({super.key});

  @override
  State<SyncProgressScreen> createState() => _SyncProgressScreenState();
}

class _SyncProgressScreenState extends State<SyncProgressScreen> {
  bool _isSyncing = false;
  String _status = 'Ready to sync';
  int _syncedCount = 0;
  int _totalCount = 0;

  @override
  void initState() {
    super.initState();
    _startSync();
  }

  Future<void> _startSync() async {
    setState(() {
      _isSyncing = true;
      _status = 'Starting sync...';
    });

    try {
      // Check authentication status from central state authority - AuthBloc
      final authState = context.read<AuthBloc>().state;

      if (authState is! Authenticated) {
        throw Exception("User is not authenticated.");
      }

      // Get the YouTube access token from the authenticated state
      final accessToken = authState.accessToken;

      if (accessToken == null) {
        throw Exception(
          "YouTube access token not available. Please sign in again.",
        );
      }

      // Use the access token to sync
      await _syncWithToken(accessToken);
    } catch (e) {
      setState(() {
        _status = 'Sync failed: $e';
        _isSyncing = false;
      });
    }
  }

  Future<void> _syncWithToken(String accessToken) async {
    // Implementation would call the sync service with the token
    setState(() {
      _status = 'Syncing your liked videos...';
    });

    // Simulate sync progress
    for (int i = 0; i <= 100; i++) {
      await Future.delayed(const Duration(milliseconds: 50));
      setState(() {
        _syncedCount = i;
        _totalCount = 100;
        _status = 'Synced $i of 100 videos';
      });
    }

    setState(() {
      _status = 'Sync completed successfully!';
      _isSyncing = false;
    });

    // Navigate back after a short delay
    await Future.delayed(const Duration(seconds: 2));
    if (mounted) {
      if (context.mounted) {
        Navigator.of(context).pop();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ZenSortScaffold(
      appBar: const AnimatedGradientAppBar(title: 'Syncing Videos'),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_isSyncing) const GradientLoader(size: 60),
            const SizedBox(height: 24),
            Text(
              _status,
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(color: Colors.white),
              textAlign: TextAlign.center,
            ),
            if (_totalCount > 0) ...[
              const SizedBox(height: 16),
              LinearProgressIndicator(
                value: _totalCount > 0 ? _syncedCount / _totalCount : 0,
                backgroundColor: Colors.white24,
                valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
              ),
              const SizedBox(height: 8),
              Text(
                '$_syncedCount / $_totalCount videos',
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: Colors.white70),
              ),
            ],
            if (!_isSyncing) ...[
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Done'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
