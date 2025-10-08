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
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: TextField(
        controller: _controller,
        onChanged: (value) => context.read<YouTubeBloc>().add(SearchQueryChanged(value)),
        decoration: InputDecoration(
          hintText: 'Search liked videos...',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: IconButton(
            icon: const Icon(Icons.clear),
            onPressed: () {
              if (_controller.text.isEmpty) return;
              _controller.clear();
              FocusScope.of(context).unfocus();
              context.read<YouTubeBloc>().add(const SearchQueryChanged(''));
            },
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(30.0),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: Colors.grey[200],
        ),
      ),
    );
  }
}
