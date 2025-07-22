import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:zensort/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:zensort/features/youtube/presentation/bloc/youtube_bloc.dart';
import 'package:zensort/features/youtube/presentation/widgets/video_list_item.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    // Load the already synced videos from Firestore when the screen loads
    context.read<YouTubeBloc>().add(GetMyLikedVideos());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Liked Videos'),
        actions: [
          IconButton(
            icon: const Icon(Icons.sync),
            onPressed: () {
              final authState = context.read<AuthBloc>().state;
              if (authState is Authenticated) {
                context.read<YouTubeBloc>().add(
                  SyncMyLikedVideos(authState.accessToken),
                );
              } else {
                // This case should ideally not be reached if the user is on this screen
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Authentication error. Please sign in again.',
                    ),
                  ),
                );
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              // Use the correct SignOut event
              context.read<AuthBloc>().add(SignOut());
            },
          ),
        ],
      ),
      body: BlocConsumer<YouTubeBloc, YouTubeState>(
        listener: (context, state) {
          if (state is YouTubeSyncSuccess) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(const SnackBar(content: Text('Sync successful!')));
          }
          if (state is YouTubeFailure) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('An error occurred: ${state.error}')),
            );
          }
        },
        builder: (context, state) {
          if (state is YouTubeLoading || state is YouTubeInitial) {
            return const Center(child: CircularProgressIndicator());
          }
          if (state is YouTubeSyncInProgress) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Syncing your liked videos...'),
                ],
              ),
            );
          }
          if (state is YouTubeSuccess) {
            if (state.videos.isEmpty) {
              return const Center(
                child: Text('No liked videos found. Try syncing!'),
              );
            }
            return ListView.builder(
              itemCount: state.videos.length,
              itemBuilder: (context, index) {
                return VideoListItem(video: state.videos[index]);
              },
            );
          }
          // Fallback for any other state
          return const Center(child: Text('Welcome! Please sync your videos.'));
        },
      ),
    );
  }
}
