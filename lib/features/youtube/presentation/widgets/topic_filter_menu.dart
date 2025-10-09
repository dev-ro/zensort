import 'package:flutter/material.dart';

class TopicFilterMenu extends StatefulWidget {
  final List<String> availableTopics;
  final String? selectedTopic;
  final ValueChanged<String?> onSelected;

  const TopicFilterMenu({
    super.key,
    required this.availableTopics,
    required this.selectedTopic,
    required this.onSelected,
  });

  @override
  State<TopicFilterMenu> createState() => _TopicFilterMenuState();
}

class _TopicFilterMenuState extends State<TopicFilterMenu> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<String> _filteredTopics() {
    final q = _searchController.text.trim().toLowerCase();
    if (q.isEmpty) return widget.availableTopics;
    return widget.availableTopics
        .where((t) => t.toLowerCase().contains(q))
        .toList();
  }

  void _selectTopic(String? topic) {
    if (topic == null) {
      widget.onSelected(null);
      return;
    }
    // Deselect if tapping the same topic again
    if (widget.selectedTopic != null && widget.selectedTopic == topic) {
      widget.onSelected(null);
    } else {
      widget.onSelected(topic);
    }
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isDesktop = width >= 800;
    final label = widget.selectedTopic == null || widget.selectedTopic!.isEmpty
        ? 'Topics: All'
        : 'Topics: ${widget.selectedTopic}';

    if (isDesktop) {
      return _DesktopTopicMenu(
        label: label,
        searchController: _searchController,
        topicsBuilder: _filteredTopics,
        onSelect: _selectTopic,
      );
    }

    return _MobileTopicMenu(
      label: label,
      searchController: _searchController,
      topicsBuilder: _filteredTopics,
      onSelect: _selectTopic,
    );
  }
}

class _DesktopTopicMenu extends StatefulWidget {
  final String label;
  final TextEditingController searchController;
  final List<String> Function() topicsBuilder;
  final ValueChanged<String?> onSelect;

  const _DesktopTopicMenu({
    required this.label,
    required this.searchController,
    required this.topicsBuilder,
    required this.onSelect,
  });

  @override
  State<_DesktopTopicMenu> createState() => _DesktopTopicMenuState();
}

class _DesktopTopicMenuState extends State<_DesktopTopicMenu> {
  final MenuController _menuController = MenuController();

  @override
  Widget build(BuildContext context) {
    return MenuAnchor(
      controller: _menuController,
      alignmentOffset: const Offset(0, 8),
      menuChildren: [
        ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: 360,
            maxHeight: 420,
            minWidth: 280,
          ),
          child: Material(
            color: Theme.of(context).colorScheme.surface,
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: widget.searchController,
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(
                      hintText: 'Search topics...',
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: Scrollbar(
                      child: ListView(
                        children: [
                          RadioListTile<String>(
                            value: '',
                            groupValue: widget.label == 'Topics: All' ? '' : 'x',
                            title: const Text('All topics'),
                            onChanged: (_) {
                              widget.onSelect(null);
                              _menuController.close();
                            },
                          ),
                          ...widget.topicsBuilder().map((topic) {
                            final isSelected = topic ==
                                (widget.label.startsWith('Topics: ')
                                    ? widget.label.substring(8)
                                    : null);
                            return RadioListTile<String>(
                              value: topic,
                              groupValue: isSelected ? topic : null,
                              title: Text(topic),
                              onChanged: (_) {
                                widget.onSelect(topic);
                                _menuController.close();
                              },
                            );
                          }),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
      child: Semantics(
        label: widget.label,
        button: true,
        child: FilledButton.tonal(
          onPressed: () {
            if (_menuController.isOpen) {
              _menuController.close();
            } else {
              _menuController.open();
            }
          },
          child: Text(widget.label),
        ),
      ),
    );
  }
}

class _MobileTopicMenu extends StatelessWidget {
  final String label;
  final TextEditingController searchController;
  final List<String> Function() topicsBuilder;
  final ValueChanged<String?> onSelect;

  const _MobileTopicMenu({
    required this.label,
    required this.searchController,
    required this.topicsBuilder,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: label,
      button: true,
      child: FilledButton.tonal(
        onPressed: () async {
          await showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            builder: (context) {
              return DraggableScrollableSheet(
                expand: false,
                minChildSize: 0.5,
                maxChildSize: 0.95,
                builder: (context, controller) {
                  return Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TextField(
                          controller: searchController,
                          onChanged: (_) {
                            // Trigger rebuild via StatefulBuilder
                            (context as Element).markNeedsBuild();
                          },
                          decoration: const InputDecoration(
                            hintText: 'Search topics...',
                            isDense: true,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Expanded(
                          child: Scrollbar(
                            child: ListView.builder(
                              controller: controller,
                              itemCount: topicsBuilder().length + 1,
                              itemBuilder: (context, index) {
                                if (index == 0) {
                                  return ListTile(
                                    title: const Text('All topics'),
                                    onTap: () {
                                      onSelect(null);
                                      Navigator.of(context).pop();
                                    },
                                  );
                                }
                                final topic = topicsBuilder()[index - 1];
                                return ListTile(
                                  title: Text(topic),
                                  onTap: () {
                                    onSelect(topic);
                                    Navigator.of(context).pop();
                                  },
                                );
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          );
        },
        child: Text(label),
      ),
    );
  }
}
