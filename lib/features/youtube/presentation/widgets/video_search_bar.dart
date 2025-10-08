import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:zensort/features/youtube/presentation/bloc/youtube_bloc.dart';

class VideoSearchBar extends StatefulWidget {
  const VideoSearchBar({super.key});

  @override
  State<VideoSearchBar> createState() => _VideoSearchBarState();
}

class _VideoSearchBarState extends State<VideoSearchBar> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: TextField(
        controller: _controller,
        onChanged: (value) => context.read<YouTubeBloc>().add(SearchQueryChanged(value)),
        style: TextStyle(color: colorScheme.onSurface),
        decoration: InputDecoration(
          hintText: 'Search liked videos...',
          hintStyle: TextStyle(color: colorScheme.onSurfaceVariant),
          prefixIcon: Icon(Icons.search, color: colorScheme.onSurfaceVariant),
          suffixIcon: IconButton(
            icon: Icon(Icons.clear, color: colorScheme.onSurfaceVariant),
            onPressed: () {
              if (_controller.text.isEmpty) return;
              _controller.clear();
              FocusScope.of(context).unfocus();
              context.read<YouTubeBloc>().add(const SearchQueryChanged(''));
            },
          ),
          filled: true,
          fillColor: colorScheme.surfaceVariant,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12.0),
            borderSide: BorderSide(color: colorScheme.outlineVariant, width: 1),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12.0),
            borderSide: BorderSide(color: colorScheme.outlineVariant, width: 1),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12.0),
            borderSide: BorderSide(color: colorScheme.primary, width: 1.5),
          ),
        ),
      ),
    );
  }
}
