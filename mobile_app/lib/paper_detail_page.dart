import 'package:flutter/cupertino.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'acadex_constants.dart';
import 'paper.dart';
import 'paper_slide_viewer.dart';

class PaperDetailPage extends StatefulWidget {
  const PaperDetailPage({super.key, required this.paper});

  final Paper paper;

  @override
  State<PaperDetailPage> createState() => _PaperDetailPageState();
}

class _PaperDetailPageState extends State<PaperDetailPage> {
  List<Paper>? _batch;
  late final PageController _pageController;
  int _pageIndex = 0;
  Map<String, String> _uploaderNames = const {};

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _loadBatch();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _loadBatch() async {
    try {
      final bid = widget.paper.uploadBatchId;
      if (bid == null) {
        await _loadUploaderNames([widget.paper.uploadedBy]);
        if (!mounted) return;
        setState(() {
          _batch = [widget.paper];
          _pageIndex = 0;
        });
        return;
      }

      final rows = await Supabase.instance.client
          .from(kPapersTable)
          .select()
          .eq('upload_batch_id', bid)
          .order('created_at', ascending: true);

      final list = (rows as List<dynamic>)
          .map((e) => Paper.fromMap(Map<String, dynamic>.from(e as Map)))
          .toList();
      await _loadUploaderNames(list.map((p) => p.uploadedBy));

      if (!mounted) return;

      final idx = list.indexWhere((p) => p.id == widget.paper.id);
      final start = idx >= 0 ? idx : 0;

      setState(() {
        _batch = list.isEmpty ? [widget.paper] : list;
        _pageIndex = start;
      });

      if (start > 0) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_pageController.hasClients) {
            _pageController.jumpToPage(start);
          }
        });
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _batch = [widget.paper];
        _pageIndex = 0;
      });
    }
  }

  Future<void> _loadUploaderNames(Iterable<String> uploaderIds) async {
    final ids = uploaderIds
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toSet()
        .toList();
    if (ids.isEmpty) {
      if (!mounted) return;
      setState(() => _uploaderNames = const {});
      return;
    }
    try {
      final rows = await Supabase.instance.client
          .from(kPublicUsersTable)
          .select('id, username')
          .inFilter('id', ids);
      if (!mounted) return;
      final next = <String, String>{};
      for (final raw in rows as List<dynamic>) {
        final row = Map<String, dynamic>.from(raw as Map);
        final id = (row['id'] as String?)?.trim();
        final username = (row['username'] as String?)?.trim();
        if (id != null && id.isNotEmpty && username != null && username.isNotEmpty) {
          next[id] = username;
        }
      }
      setState(() => _uploaderNames = next);
    } catch (_) {
      if (!mounted) return;
      setState(() => _uploaderNames = const {});
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_batch == null) {
      return const CupertinoPageScaffold(
        navigationBar: CupertinoNavigationBar(
          middle: Text('Preview'),
          border: null,
        ),
        child: Center(child: CupertinoActivityIndicator()),
      );
    }

    final batch = _batch!;
    final current = batch[_pageIndex.clamp(0, batch.length - 1)];
    final showCounter = batch.length > 1;
    final uploaderLabel = _uploaderNames[current.uploadedBy] ?? 'Unknown';

    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.systemGroupedBackground,
      navigationBar: CupertinoNavigationBar(
        middle: Text(
          showCounter
              ? '${current.title}  (${_pageIndex + 1}/${batch.length})'
              : current.title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
        ),
        border: null,
      ),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (current.hasMetaDisplay)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 4),
                child: Text(
                  current.metaDisplay,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: CupertinoColors.secondaryLabel.resolveFrom(context),
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
              child: Text(
                'Uploaded by ($uploaderLabel)',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: CupertinoColors.secondaryLabel.resolveFrom(context),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
              child: Text(
                current.createdAt.toLocal().toString(),
                style: TextStyle(
                  fontSize: 13,
                  color: CupertinoColors.secondaryLabel.resolveFrom(context),
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: PageView.builder(
                  controller: _pageController,
                  itemCount: batch.length,
                  onPageChanged: (i) => setState(() => _pageIndex = i),
                  itemBuilder: (context, i) {
                    return PaperSlideViewer(
                      key: ValueKey<String>(batch[i].id),
                      paper: batch[i],
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
