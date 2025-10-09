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
    return widget.availableTopics.where((t) => t.toLowerCase().contains(q)).toList();
  }

  void _selectTopic(String? topic) {
    if (topic == null) {
      widget.onSelected(null);
      return;
    }
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
        selectedTopic: widget.selectedTopic,
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
  final String? selectedTopic;

  const _DesktopTopicMenu({
    required this.label,
    required this.searchController,
    required this.topicsBuilder,
    required this.onSelect,
    this.selectedTopic,
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
        Material(
          color: Theme.of(context).colorScheme.surface,
          elevation: 2,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              minWidth: 280,
              maxWidth: 360,
            ),
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
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
                  SizedBox(
                    height: 360,
                    child: Scrollbar(
                      child: ListView(
                        shrinkWrap: true,
                        children: [
                          RadioListTile<String>(
                            value: '',
                            groupValue: (widget.selectedTopic ?? ''),
                            title: const Text('All topics'),
                            onChanged: (_) {
                              widget.onSelect(null);
                              _menuController.close();
                            },
                          ),
                          ...widget.topicsBuilder().map((topic) {
                            return RadioListTile<String>(
                              value: topic,
                              groupValue: widget.selectedTopic,
                              title: Text(topic),
                              onChanged: (_) {
                                if (widget.selectedTopic == topic) {
                                  widget.onSelect(null);
                                } else {
                                  widget.onSelect(topic);
                                }
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
              return StatefulBuilder(
                builder: (context, setSheetState) {
                  return DraggableScrollableSheet(
                    expand: false,
                    minChildSize: 0.5,
                    maxChildSize: 0.95,
                    builder: (context, controller) {
                      final items = topicsBuilder();
                      return Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            TextField(
                              controller: searchController,
                              onChanged: (_) => setSheetState(() {}),
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
                                  itemCount: items.length + 1,
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
                                    final topic = items[index - 1];
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
          );
        },
        child: Text(label),
      ),
    );
  }
}
