import 'package:flutter/cupertino.dart';

class CatalogItem {
  const CatalogItem({required this.id, required this.name});

  final String id;
  final String name;
}

/// Searchable list + create-new. Returns picked [CatalogItem] or null.
Future<CatalogItem?> showCatalogPickerSheet(
  BuildContext context, {
  required String title,
  required List<CatalogItem> items,
  required Future<CatalogItem?> Function(String trimmedName) onCreateNew,
}) {
  return showCupertinoModalPopup<CatalogItem>(
    context: context,
    builder: (ctx) => _CatalogPickerBody(
      title: title,
      items: items,
      onCreateNew: onCreateNew,
    ),
  );
}

class _CatalogPickerBody extends StatefulWidget {
  const _CatalogPickerBody({
    required this.title,
    required this.items,
    required this.onCreateNew,
  });

  final String title;
  final List<CatalogItem> items;
  final Future<CatalogItem?> Function(String trimmedName) onCreateNew;

  @override
  State<_CatalogPickerBody> createState() => _CatalogPickerBodyState();
}

class _CatalogPickerBodyState extends State<_CatalogPickerBody> {
  final _search = TextEditingController();
  final _newName = TextEditingController();
  String _query = '';
  bool _creating = false;

  @override
  void dispose() {
    _search.dispose();
    _newName.dispose();
    super.dispose();
  }

  List<CatalogItem> get _filtered {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return widget.items;
    return widget.items
        .where((e) => e.name.toLowerCase().contains(q))
        .toList();
  }

  Future<void> _submitNew() async {
    final name = _newName.text.trim();
    if (name.isEmpty) return;
    setState(() => _creating = true);
    try {
      final created = await widget.onCreateNew(name);
      if (!mounted) return;
      if (created != null) {
        Navigator.of(context).pop(created);
      }
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }

  List<Widget> _resultTiles(BuildContext context) {
    final filtered = _filtered;
    if (filtered.isEmpty) {
      return [
        CupertinoListTile.notched(
          title: Text(
            'No matches',
            style: TextStyle(
              color: CupertinoColors.secondaryLabel.resolveFrom(context),
            ),
          ),
        ),
      ];
    }
    return [
      for (var i = 0; i < filtered.length; i++)
        CupertinoListTile.notched(
          title: Text(
            filtered[i].name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: const CupertinoListTileChevron(),
          onTap: () => Navigator.of(context).pop(filtered[i]),
        ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    final labelStyle = TextStyle(
      fontSize: 13,
      letterSpacing: -0.08,
      color: CupertinoColors.secondaryLabel.resolveFrom(context),
    );

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.74,
      minChildSize: 0.42,
      maxChildSize: 0.96,
      builder: (context, scrollController) {
        return DecoratedBox(
          decoration: BoxDecoration(
            color: CupertinoColors.systemGroupedBackground.resolveFrom(context),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 8),
              Center(
                child: Container(
                  width: 36,
                  height: 5,
                  decoration: BoxDecoration(
                    color: CupertinoColors.systemFill.resolveFrom(context),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 10, 8, 0),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Text(
                      widget.title,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        color: CupertinoColors.label.resolveFrom(context),
                      ),
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: CupertinoButton(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        minimumSize: Size.zero,
                        onPressed: () => Navigator.of(context).pop(),
                        child: Text(
                          'Done',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                            color: CupertinoColors.activeBlue.resolveFrom(context),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Tight to nav: search sits directly under title row
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 6, 20, 0),
                child: CupertinoSearchTextField(
                  controller: _search,
                  placeholder: 'Search',
                  onChanged: (v) => setState(() => _query = v),
                  style: TextStyle(
                    color: CupertinoColors.label.resolveFrom(context),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: CustomScrollView(
                  controller: scrollController,
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                      sliver: SliverToBoxAdapter(
                        child: CupertinoListSection.insetGrouped(
                          margin: EdgeInsets.zero,
                          hasLeading: false,
                          children: _resultTiles(context),
                        ),
                      ),
                    ),
                    SliverPadding(
                      padding: EdgeInsets.fromLTRB(20, 0, 20, 12 + bottom),
                      sliver: SliverToBoxAdapter(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding:
                                  const EdgeInsetsDirectional.only(start: 20, bottom: 6),
                              child: Text(
                                'CREATE NEW',
                                style: labelStyle,
                              ),
                            ),
                            DecoratedBox(
                              decoration: BoxDecoration(
                                color: CupertinoColors.secondarySystemGroupedBackground
                                    .resolveFrom(context),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    CupertinoTextField(
                                      controller: _newName,
                                      placeholder: 'New name',
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 14,
                                        vertical: 12,
                                      ),
                                      decoration: BoxDecoration(
                                        color: CupertinoColors.systemBackground
                                            .resolveFrom(context),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    CupertinoButton.filled(
                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                      borderRadius: BorderRadius.circular(10),
                                      onPressed: _creating ? null : _submitNew,
                                      child: _creating
                                          ? const CupertinoActivityIndicator(
                                              color: CupertinoColors.white,
                                            )
                                          : const Text('Add'),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
