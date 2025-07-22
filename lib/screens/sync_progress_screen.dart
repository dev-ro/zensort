import 'package:flutter/material.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:zensort/widgets/animated_gradient_app_bar.dart';
import 'package:zensort/widgets/zen_sort_scaffold.dart';
import 'package:zensort/theme.dart';

class SyncProgressScreen extends StatefulWidget {
  const SyncProgressScreen({super.key});

  @override
  State<SyncProgressScreen> createState() => _SyncProgressScreenState();
}

class _SyncProgressScreenState extends State<SyncProgressScreen> {
  int _totalVideos = 0;
  int _syncedVideos = 0;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _startSync();
  }

  Future<void> _startSync() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception("User is not authenticated.");
      }
      final idToken = await user.getIdToken();

      final getTotalVideosCallable = FirebaseFunctions.instance.httpsCallable('get_liked_videos_total');
      final totalResult = await getTotalVideosCallable.call({'access_token': idToken});
      setState(() {
        _totalVideos = totalResult.data['total'];
      });

      final syncCallable = FirebaseFunctions.instance.httpsCallable('sync_youtube_liked_videos');
      final syncResult = await syncCallable.call({'access_token': idToken});

      setState(() {
        _syncedVideos = syncResult.data['synced'];
        _isLoading = false;
      });
    } on FirebaseFunctionsException catch (e) {
      setState(() {
        _error = e.message;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = "An unknown error occurred.";
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return ZenSortScaffold(
      appBar: const AnimatedGradientAppBar(title: 'Syncing Videos'),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_isLoading && _totalVideos == 0)
                const CircularProgressIndicator()
              else if (_error != null)
                Text('Error: $_error', style: const TextStyle(color: Colors.red))
              else
                SyncProgressIndicator(
                  total: _totalVideos,
                  synced: _syncedVideos,
                ),
              const SizedBox(height: 24),
              Text(
                _isLoading ? "Calculating..." : "Sync Complete!",
                style: Theme.of(context).textTheme.headlineSmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class SyncProgressIndicator extends StatelessWidget {
  final int total;
  final int synced;

  const SyncProgressIndicator({
    super.key,
    required this.total,
    required this.synced,
  });

  @override
  Widget build(BuildContext context) {
    final double progress = total > 0 ? synced / total : 0.0;

    return Column(
      children: [
        Container(
          height: 20,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            color: Colors.grey[300],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: ShaderMask(
              shaderCallback: (bounds) =>
                  ZenSortTheme.primaryGradient.createShader(
                    Rect.fromLTWH(0, 0, bounds.width, bounds.height),
                  ),
              child: LinearProgressIndicator(
                value: progress,
                backgroundColor: Colors.transparent,
                valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text('$synced / $total Videos Synced'),
      ],
    );
  }
}