import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/cupertino.dart';
import 'package:path/path.dart' as p;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import 'acadex_constants.dart';
import 'cupertino_toast.dart';
import 'catalog_picker_sheet.dart';
import 'paper.dart';
import 'paper_detail_page.dart';
import 'paper_list_group.dart';

final _usernamePattern = RegExp(r'^[a-zA-Z0-9_]{3,32}$');

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String? _accountType;
  bool _profileReady = false;
  StreamSubscription<List<Map<String, dynamic>>>? _systemMessagesUnreadSub;
  bool _hasUnreadSystemMessages = false;
  RealtimeChannel? _papersPendingChannel;
  bool _hasPendingReviewUploads = false;

  bool get _isAdmin =>
      _profileReady && (_accountType?.toLowerCase() == 'administrator');

  @override
  void initState() {
    super.initState();
    _loadAccountType();
    _subscribeSystemMessageUnread();
  }

  @override
  void dispose() {
    _systemMessagesUnreadSub?.cancel();
    if (_papersPendingChannel != null) {
      unawaited(Supabase.instance.client.removeChannel(_papersPendingChannel!));
    }
    super.dispose();
  }

  void _subscribeSystemMessageUnread() {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    _systemMessagesUnreadSub?.cancel();
    _systemMessagesUnreadSub = Supabase.instance.client
        .from(kSystemMessagesTable)
        .stream(primaryKey: const ['id'])
        .eq('user_id', user.id)
        .listen((rows) {
      final unread = rows.any((r) => r['read_at'] == null);
      if (mounted) setState(() => _hasUnreadSystemMessages = unread);
    });
  }

  Future<void> _loadAccountType() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      if (mounted) setState(() => _profileReady = true);
      return;
    }
    try {
      final row = await Supabase.instance.client
          .from(kPublicUsersTable)
          .select('account_type')
          .eq('id', user.id)
          .maybeSingle();
      if (!mounted) return;
      final isAdministrator =
          (row?['account_type'] as String?)?.toLowerCase() == 'administrator';
      setState(() {
        _accountType = row?['account_type'] as String?;
        _profileReady = true;
      });
      if (!mounted) return;
      if (isAdministrator) {
        unawaited(_ensureReviewPendingTracking());
      } else {
        _teardownReviewPendingTracking();
      }
    } catch (_) {
      if (mounted) setState(() => _profileReady = true);
    }
  }

  Future<void> _refreshPendingReviewFlag() async {
    if (!_isAdmin) {
      if (mounted) setState(() => _hasPendingReviewUploads = false);
      return;
    }
    try {
      final rows = await Supabase.instance.client
          .from(kPapersTable)
          .select('id')
          .eq('approval_status', 'pending')
          .limit(1);
      final has = rows.isNotEmpty;
      if (mounted) setState(() => _hasPendingReviewUploads = has);
    } catch (_) {
      if (mounted) setState(() => _hasPendingReviewUploads = false);
    }
  }

  void _teardownReviewPendingTracking() {
    if (_papersPendingChannel != null) {
      unawaited(Supabase.instance.client.removeChannel(_papersPendingChannel!));
      _papersPendingChannel = null;
    }
    if (mounted) setState(() => _hasPendingReviewUploads = false);
  }

  Future<void> _ensureReviewPendingTracking() async {
    await _refreshPendingReviewFlag();
    if (!mounted || !_isAdmin) return;
    if (_papersPendingChannel != null) {
      unawaited(Supabase.instance.client.removeChannel(_papersPendingChannel!));
    }
    final ch = Supabase.instance.client.channel('review_uploads_pending_tab');
    ch.onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: kPapersTable,
      callback: (_) {
        unawaited(_refreshPendingReviewFlag());
      },
    ).subscribe();
    _papersPendingChannel = ch;
  }

  @override
  Widget build(BuildContext context) {
    if (!_profileReady) {
      return const CupertinoPageScaffold(
        child: Center(child: CupertinoActivityIndicator()),
      );
    }

    return CupertinoTabScaffold(
      tabBar: CupertinoTabBar(
        backgroundColor:
            CupertinoColors.systemBackground.withValues(alpha: 0.92),
        items: [
          BottomNavigationBarItem(
            icon: _tabIcon(CupertinoIcons.doc_on_doc),
            activeIcon: _tabIcon(CupertinoIcons.doc_on_doc_fill),
            label: 'Papers',
          ),
          BottomNavigationBarItem(
            icon: _isAdmin
                ? _reviewUploadsTabIcon(
                    icon: CupertinoIcons.list_bullet,
                    hasPending: _hasPendingReviewUploads,
                  )
                : _tabIcon(CupertinoIcons.tray_arrow_up),
            activeIcon: _isAdmin
                ? _reviewUploadsTabIcon(
                    icon: CupertinoIcons.list_bullet,
                    hasPending: _hasPendingReviewUploads,
                  )
                : _tabIcon(CupertinoIcons.tray_arrow_up_fill),
            label: _isAdmin ? 'Review Uploads' : 'My Uploads',
          ),
          BottomNavigationBarItem(
            icon: _tabIcon(CupertinoIcons.person_crop_circle),
            activeIcon: _tabIcon(CupertinoIcons.person_crop_circle_fill),
            label: 'User',
          ),
        ],
      ),
      tabBuilder: (context, index) {
        switch (index) {
          case 0:
            return _PapersTab(
              hasUnreadSystemMessages: _hasUnreadSystemMessages,
              isAdmin: _isAdmin,
            );
          case 1:
            return _isAdmin
                ? _ReviewUploadsTab(hasUnreadSystemMessages: _hasUnreadSystemMessages)
                : _UploadsTab(hasUnreadSystemMessages: _hasUnreadSystemMessages);
          case 2:
            return _UserTab(
              isAdmin: _isAdmin,
              hasUnreadSystemMessages: _hasUnreadSystemMessages,
            );
          default:
            return _PapersTab(
              hasUnreadSystemMessages: _hasUnreadSystemMessages,
              isAdmin: _isAdmin,
            );
        }
      },
    );
  }
}

Widget _tabIcon(IconData icon) {
  return SizedBox(
    height: 24,
    width: 24,
    child: Center(
      child: Icon(icon, size: 22),
    ),
  );
}

Widget _reviewUploadsTabIcon({
  required IconData icon,
  required bool hasPending,
}) {
  return SizedBox(
    height: 24,
    width: 24,
    child: Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.center,
      children: [
        Icon(icon, size: 22),
        if (hasPending)
          Positioned(
            right: -1,
            top: -1,
            child: Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: Color(0xFFEF4444),
                shape: BoxShape.circle,
              ),
            ),
          ),
      ],
    ),
  );
}

Widget _messagesTabIcon({required IconData icon, required bool hasUnread}) {
  return SizedBox(
    height: 24,
    width: 24,
    child: Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.center,
      children: [
        Icon(icon, size: 22),
        if (hasUnread)
          Positioned(
            right: -1,
            top: -1,
            child: Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: Color(0xFFEF4444),
                shape: BoxShape.circle,
              ),
            ),
          ),
      ],
    ),
  );
}

/// Opens system messages (same as web sidebar mail icon); used in nav bar trailing.
class _NavMailButton extends StatelessWidget {
  const _NavMailButton({required this.hasUnread});

  final bool hasUnread;

  @override
  Widget build(BuildContext context) {
    return CupertinoButton(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      minimumSize: Size.zero,
      onPressed: () {
        Navigator.of(context).push(
          CupertinoPageRoute<void>(
            builder: (ctx) => const _SystemMessagesTab(),
          ),
        );
      },
      child: _messagesTabIcon(
        icon: CupertinoIcons.envelope,
        hasUnread: hasUnread,
      ),
    );
  }
}

String _formatSystemMessageTime(String iso) {
  final d = DateTime.tryParse(iso)?.toLocal();
  if (d == null) return iso;
  final y = d.year.toString();
  final mo = d.month.toString().padLeft(2, '0');
  final da = d.day.toString().padLeft(2, '0');
  final h = d.hour.toString().padLeft(2, '0');
  final mi = d.minute.toString().padLeft(2, '0');
  return '$y-$mo-$da $h:$mi';
}

String _systemMessageListSnippet(String body) {
  final s = body.replaceAll(RegExp(r'\s+'), ' ').trim();
  return s.isEmpty ? '—' : s;
}

Widget _systemMessageInboxRow(
  BuildContext context,
  Map<String, dynamic> row, {
  required VoidCallback onOpen,
  required VoidCallback onDelete,
  required bool deleteBusy,
}) {
  final title = row['title'] as String? ?? '';
  final body = row['body'] as String? ?? '';
  final createdAt = row['created_at'] as String? ?? '';
  final isUnread = row['read_at'] == null;
  final labelColor = CupertinoColors.label.resolveFrom(context);
  final secondary = CupertinoColors.secondaryLabel.resolveFrom(context);
  final bg = isUnread
      ? CupertinoColors.systemBackground.resolveFrom(context)
      : CupertinoColors.systemGrey6.resolveFrom(context);

  return ColoredBox(
    color: bg,
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: CupertinoButton(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            minimumSize: Size.zero,
            onPressed: onOpen,
            child: Row(
              children: [
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 132),
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: isUnread ? FontWeight.w700 : FontWeight.w600,
                      color: labelColor,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _systemMessageListSnippet(body),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                      color: secondary,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  _formatSystemMessageTime(createdAt),
                  style: TextStyle(
                    fontSize: 12,
                    color: secondary,
                  ),
                ),
              ],
            ),
          ),
        ),
        CupertinoButton(
          padding: const EdgeInsets.fromLTRB(4, 8, 8, 8),
          minimumSize: Size.zero,
          onPressed: deleteBusy ? null : onDelete,
          child: Icon(
            CupertinoIcons.trash,
            size: 20,
            color: CupertinoColors.destructiveRed.resolveFrom(context),
          ),
        ),
      ],
    ),
  );
}

class _PapersTab extends StatefulWidget {
  const _PapersTab({
    required this.hasUnreadSystemMessages,
    required this.isAdmin,
  });

  final bool hasUnreadSystemMessages;
  final bool isAdmin;

  @override
  State<_PapersTab> createState() => _PapersTabState();
}

class _PapersTabState extends State<_PapersTab> {
  /// New instance on pull-to-refresh so the list reloads from PostgREST + Realtime.
  late Stream<List<Map<String, dynamic>>> _papersStream;
  final _searchController = TextEditingController();

  String? _filterSchoolName;
  int? _filterGrade;
  String? _filterCourseName;
  int? _filterPaperYear;
  String? _filterSemester;
  bool _adminDeleteBusy = false;

  @override
  void initState() {
    super.initState();
    _papersStream = _createPapersStream();
    _searchController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Stream<List<Map<String, dynamic>>> _createPapersStream() {
    return Supabase.instance.client
        .from(kPapersTable)
        .stream(primaryKey: const ['id'])
        .eq('approval_status', 'approved')
        .order('created_at', ascending: false);
  }

  Future<void> _onRefresh() async {
    setState(() {
      _papersStream = _createPapersStream();
    });
  }

  Future<void> _confirmAdminDeleteGroup(PaperListGroup group) async {
    final n = group.count;
    await showCupertinoDialog<void>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('Delete paper?'),
        content: Text(
          n > 1
              ? 'This will remove $n file(s) from storage and the database.'
              : 'This will remove the file from storage and the database.',
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () async {
              Navigator.of(ctx).pop();
              await _deleteAdminGroup(group);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteAdminGroup(PaperListGroup group) async {
    if (_adminDeleteBusy) return;
    setState(() => _adminDeleteBusy = true);
    try {
      final ids = group.papers.map((p) => p.id).toList();
      final paths = group.papers.map((p) => p.storagePath).toList();

      await Supabase.instance.client.rpc(
        'admin_notify_papers_deleted',
        params: {'p_paper_ids': ids},
      );

      await Supabase.instance.client.rpc(
        'admin_delete_papers',
        params: {'p_paper_ids': ids},
      );

      await Supabase.instance.client.storage.from(kExamPapersBucket).remove(paths);

      if (mounted) await _onRefresh();
      if (mounted) {
        showAcadexToast(
          context,
          group.count > 1 ? 'Papers deleted' : 'Paper deleted',
          variant: AcadexToastVariant.danger,
        );
      }
    } catch (e) {
      if (mounted) {
        showAcadexToast(context, e.toString(), variant: AcadexToastVariant.danger);
      }
    } finally {
      if (mounted) setState(() => _adminDeleteBusy = false);
    }
  }

  List<Paper> _applyPapersFilters(List<Paper> papers) {
    final needle = _searchController.text.trim().toLowerCase();
    bool textMatch(Paper p) {
      if (needle.isEmpty) return true;
      final blob = [
        p.title,
        p.schoolName,
        p.courseName,
        if (p.grade != null) '${p.grade}',
        if (p.paperYear != null) '${p.paperYear}',
        p.semester,
        p.paperVersion,
        p.metaDisplay,
      ].whereType<String>().join(' ').toLowerCase();
      return blob.contains(needle);
    }
    return papers.where((p) {
      if (_filterSchoolName != null &&
          (p.schoolName ?? '') != _filterSchoolName) {
        return false;
      }
      if (_filterGrade != null && p.grade != _filterGrade) return false;
      if (_filterCourseName != null &&
          (p.courseName ?? '') != _filterCourseName) {
        return false;
      }
      if (_filterPaperYear != null && p.paperYear != _filterPaperYear) {
        return false;
      }
      if (_filterSemester != null && (p.semester ?? '') != _filterSemester) {
        return false;
      }
      return textMatch(p);
    }).toList();
  }

  Future<void> _showFilterSheet({
    required String title,
    required List<String?> values,
    required void Function(String? next) onPick,
    String allLabel = 'All',
  }) async {
    await showCupertinoModalPopup<void>(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: Text(title),
        actions: [
          for (final v in values)
            CupertinoActionSheetAction(
              onPressed: () {
                Navigator.pop(ctx);
                setState(() => onPick(v));
              },
              child: Text(v ?? allLabel),
            ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Cancel'),
        ),
      ),
    );
  }

  Future<void> _showYearFilterSheet(List<int> yearsInData) async {
    final sortedYears = yearsInData.toSet().toList()
      ..sort((a, b) => b.compareTo(a));
    final years = <int?>[null, ...sortedYears];
    await showCupertinoModalPopup<void>(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: const Text('Year'),
        actions: [
          for (final y in years)
            CupertinoActionSheetAction(
              onPressed: () {
                Navigator.pop(ctx);
                setState(() => _filterPaperYear = y);
              },
              child: Text(y == null ? 'All years' : '$y'),
            ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Cancel'),
        ),
      ),
    );
  }

  Widget _filterChip(
    BuildContext context,
    String label,
    String value,
    VoidCallback onTap,
  ) {
    return CupertinoButton(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      minimumSize: Size.zero,
      onPressed: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: CupertinoColors.secondarySystemGroupedBackground
              .resolveFrom(context),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: CupertinoColors.separator.resolveFrom(context),
          ),
        ),
        child: Text(
          '$label: $value',
          style: const TextStyle(fontSize: 13),
        ),
      ),
    );
  }

  Widget _papersFilterBar(List<Paper> allPapers) {
    final schools = allPapers
        .map((p) => p.schoolName)
        .whereType<String>()
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toSet()
        .toList()
      ..sort((a, b) => a.compareTo(b));
    final courses = allPapers
        .map((p) => p.courseName)
        .whereType<String>()
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toSet()
        .toList()
      ..sort((a, b) => a.compareTo(b));
    final grades = allPapers
        .map((p) => p.grade)
        .whereType<int>()
        .toSet()
        .toList()
      ..sort();
    final yearsInData = allPapers
        .map((p) => p.paperYear)
        .whereType<int>()
        .toList();

    Future<void> pickSchool() => _showFilterSheet(
          title: 'School',
          values: [null, ...schools],
          allLabel: 'All schools',
          onPick: (v) => _filterSchoolName = v,
        );

    Future<void> pickGrade() async {
      final vals = <String?>[null, ...grades.map((g) => '$g')];
      await showCupertinoModalPopup<void>(
        context: context,
        builder: (ctx) => CupertinoActionSheet(
          title: const Text('Grade'),
          actions: [
            for (final s in vals)
              CupertinoActionSheetAction(
                onPressed: () {
                  Navigator.pop(ctx);
                  setState(() {
                    _filterGrade = s == null ? null : int.tryParse(s);
                  });
                },
                child: Text(s == null ? 'All grades' : 'Grade $s'),
              ),
          ],
          cancelButton: CupertinoActionSheetAction(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
        ),
      );
    }

    Future<void> pickCourse() => _showFilterSheet(
          title: 'Course code',
          values: [null, ...courses],
          allLabel: 'All course codes',
          onPick: (v) => _filterCourseName = v,
        );

    Future<void> pickSemester() => _showFilterSheet(
          title: 'Semester',
          values: [null, ...kPaperSemesters],
          allLabel: 'All semesters',
          onPick: (v) => _filterSemester = v,
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CupertinoSearchTextField(
          controller: _searchController,
          placeholder: 'Search papers…',
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _filterChip(
              context,
              'School',
              _filterSchoolName ?? 'All',
              pickSchool,
            ),
            _filterChip(
              context,
              'Grade',
              _filterGrade == null ? 'All' : 'G$_filterGrade',
              pickGrade,
            ),
            _filterChip(
              context,
              'Course code',
              _filterCourseName ?? 'All',
              pickCourse,
            ),
            _filterChip(
              context,
              'Year',
              _filterPaperYear == null ? 'All' : '$_filterPaperYear',
              () => _showYearFilterSheet(yearsInData),
            ),
            _filterChip(
              context,
              'Semester',
              _filterSemester ?? 'All',
              pickSemester,
            ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.systemGroupedBackground,
      navigationBar: CupertinoNavigationBar(
        middle: const Text('Papers'),
        border: null,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _NavMailButton(hasUnread: widget.hasUnreadSystemMessages),
            CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: _onRefresh,
              child: const Icon(CupertinoIcons.arrow_clockwise),
            ),
          ],
        ),
      ),
      child: SafeArea(
        child: StreamBuilder<List<Map<String, dynamic>>>(
          stream: _papersStream,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    snapshot.error.toString(),
                    textAlign: TextAlign.center,
                  ),
                ),
              );
            }
            if (snapshot.connectionState == ConnectionState.waiting &&
                !snapshot.hasData) {
              return const Center(child: CupertinoActivityIndicator());
            }
            final rows = snapshot.data ?? [];
            final allPapers = rows
                .map((e) => Paper.fromMap(Map<String, dynamic>.from(e)))
                .toList();
            final filtered = _applyPapersFilters(allPapers);
            final groups = groupPapersForDisplay(filtered);
            final filterSliver = SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              sliver: SliverToBoxAdapter(
                child: _papersFilterBar(allPapers),
              ),
            );
            if (allPapers.isEmpty) {
              return CustomScrollView(
                slivers: [
                  CupertinoSliverRefreshControl(onRefresh: _onRefresh),
                  filterSliver,
                  const SliverFillRemaining(
                    child: Center(
                      child: Text('No papers yet. Upload one in My Uploads.'),
                    ),
                  ),
                ],
              );
            }
            if (groups.isEmpty) {
              return CustomScrollView(
                slivers: [
                  CupertinoSliverRefreshControl(onRefresh: _onRefresh),
                  filterSliver,
                  const SliverFillRemaining(
                    child: Center(
                      child: Text('No matching papers.'),
                    ),
                  ),
                ],
              );
            }
            return CustomScrollView(
              slivers: [
                CupertinoSliverRefreshControl(onRefresh: _onRefresh),
                filterSliver,
                SliverSafeArea(
                  top: false,
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final group = groups[index];
                        return Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 6,
                          ),
                          child: Container(
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: CupertinoColors
                                  .secondarySystemGroupedBackground
                                  .resolveFrom(context),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: CupertinoButton(
                                    padding: EdgeInsets.zero,
                                    onPressed: () {
                                      Navigator.of(context).push(
                                        CupertinoPageRoute<void>(
                                          builder: (context) => PaperDetailPage(
                                            paper: group.opener,
                                          ),
                                        ),
                                      );
                                    },
                                    child: Padding(
                                      padding: const EdgeInsets.all(14),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          if (group.opener.hasMetaDisplay) ...[
                                            Text(
                                              group.opener.metaDisplay,
                                              style: const TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w500,
                                                color: CupertinoColors.systemBlue,
                                              ),
                                            ),
                                            const SizedBox(height: 6),
                                          ],
                                          Text(
                                            group.listTitle,
                                            style: TextStyle(
                                              fontSize: 17,
                                              fontWeight: FontWeight.w600,
                                              color: CupertinoColors.label
                                                  .resolveFrom(context),
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            group.latestCreatedAt
                                                .toLocal()
                                                .toString(),
                                            style: const TextStyle(
                                              fontSize: 13,
                                              color: CupertinoColors.secondaryLabel,
                                            ),
                                          ),
                                          const SizedBox(height: 6),
                                          Text(
                                            group.count > 1
                                                ? 'Tap to preview ${group.count} items'
                                                : 'Tap to open',
                                            style: const TextStyle(
                                              fontSize: 12,
                                              color: CupertinoColors.systemBlue,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                if (widget.isAdmin)
                                  CupertinoButton(
                                    padding: EdgeInsets.zero,
                                    minimumSize: Size.zero,
                                    onPressed: _adminDeleteBusy
                                        ? null
                                        : () => _confirmAdminDeleteGroup(group),
                                    child: Padding(
                                      padding: const EdgeInsets.fromLTRB(0, 10, 14, 10),
                                      child: Icon(
                                        CupertinoIcons.trash,
                                        color: CupertinoColors.destructiveRed
                                            .resolveFrom(context),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        );
                      },
                      childCount: groups.length,
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _UploadsTab extends StatefulWidget {
  const _UploadsTab({required this.hasUnreadSystemMessages});

  final bool hasUnreadSystemMessages;

  @override
  State<_UploadsTab> createState() => _UploadsTabState();
}

class _UploadsTabState extends State<_UploadsTab> {
  final _titleController = TextEditingController();
  final _versionController = TextEditingController();
  bool _uploading = false;

  List<Map<String, dynamic>> _schoolRows = [];
  List<Map<String, dynamic>> _courseRows = [];
  String? _schoolId;
  String? _schoolName;
  String? _courseId;
  String? _courseName;
  int _grade = 10;
  int _paperYear = DateTime.now().year;
  String _semester = kPaperSemesters.first;

  Stream<List<Map<String, dynamic>>> _myUploadsStream =
      Stream.value(<Map<String, dynamic>>[]);
  bool _deleteBusy = false;

  @override
  void initState() {
    super.initState();
    _myUploadsStream = _createMyUploadsStream();
    _loadCatalog();
  }

  Stream<List<Map<String, dynamic>>> _createMyUploadsStream() {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      return Stream.value(<Map<String, dynamic>>[]);
    }
    return Supabase.instance.client
        .from(kPapersTable)
        .stream(primaryKey: const ['id'])
        .eq('uploaded_by', user.id)
        .order('created_at', ascending: false);
  }

  Future<void> _refreshMyUploads() async {
    if (!mounted) return;
    setState(() {
      _myUploadsStream = _createMyUploadsStream();
    });
  }

  Future<void> _onPullRefresh() async {
    _refreshMyUploads();
    await Future<void>.delayed(const Duration(milliseconds: 400));
  }

  Future<void> _confirmDeleteGroup(PaperListGroup group) async {
    final n = group.count;
    await showCupertinoDialog<void>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('Delete upload?'),
        content: Text(
          n > 1
              ? 'This will remove $n files from storage and the database.'
              : 'This will remove the file from storage and the database.',
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () async {
              Navigator.of(ctx).pop();
              await _deleteGroup(group);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteGroup(PaperListGroup group) async {
    if (_deleteBusy) return;
    setState(() => _deleteBusy = true);
    try {
      final paths = group.papers.map((p) => p.storagePath).toList();
      final ids = group.papers.map((p) => p.id).toList();
      await Supabase.instance.client.storage.from(kExamPapersBucket).remove(paths);
      await Supabase.instance.client.from(kPapersTable).delete().inFilter('id', ids);
      if (mounted) await _refreshMyUploads();
      if (mounted) {
        showAcadexToast(
          context,
          group.count > 1 ? 'Files Deleted' : 'File Deleted',
          variant: AcadexToastVariant.danger,
        );
      }
    } catch (e) {
      if (mounted) {
        showAcadexToast(context, e.toString(), variant: AcadexToastVariant.danger);
      }
    } finally {
      if (mounted) setState(() => _deleteBusy = false);
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _versionController.dispose();
    super.dispose();
  }

  Future<void> _loadCatalog() async {
    try {
      final s = await Supabase.instance.client
          .from(kSchoolsTable)
          .select('id,name')
          .order('name');
      final c = await Supabase.instance.client
          .from(kCoursesTable)
          .select('id,name')
          .order('name');
      if (!mounted) return;
      setState(() {
        _schoolRows = List<Map<String, dynamic>>.from(s as List<dynamic>);
        _courseRows = List<Map<String, dynamic>>.from(c as List<dynamic>);
      });
    } catch (_) {
      /* empty catalogs ok before migration */
    }
  }

  Future<void> _pickSchool() async {
    final items = _schoolRows
        .map(
          (e) => CatalogItem(
            id: e['id'] as String,
            name: e['name'] as String,
          ),
        )
        .toList();
    final picked = await showCatalogPickerSheet(
      context,
      title: 'School',
      items: items,
      onCreateNew: (name) async {
        final row = await Supabase.instance.client
            .from(kSchoolsTable)
            .insert({'name': name})
            .select('id,name')
            .single();
        await _loadCatalog();
        return CatalogItem(
          id: row['id'] as String,
          name: row['name'] as String,
        );
      },
    );
    if (picked != null && mounted) {
      setState(() {
        _schoolId = picked.id;
        _schoolName = picked.name;
      });
    }
  }

  Future<void> _pickCourse() async {
    final items = _courseRows
        .map(
          (e) => CatalogItem(
            id: e['id'] as String,
            name: e['name'] as String,
          ),
        )
        .toList();
    final picked = await showCatalogPickerSheet(
      context,
      title: 'Course code',
      items: items,
      onCreateNew: (name) async {
        final row = await Supabase.instance.client
            .from(kCoursesTable)
            .insert({'name': name})
            .select('id,name')
            .single();
        await _loadCatalog();
        return CatalogItem(
          id: row['id'] as String,
          name: row['name'] as String,
        );
      },
    );
    if (picked != null && mounted) {
      setState(() {
        _courseId = picked.id;
        _courseName = picked.name;
      });
    }
  }

  Future<void> _pickUploadYear() async {
    final years = paperYearChoicesForUpload();
    var temp = _paperYear;
    var initial = years.indexOf(_paperYear);
    if (initial < 0) initial = 0;
    final controller = FixedExtentScrollController(initialItem: initial);
    await showCupertinoModalPopup<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Container(
          height: 280,
          color: CupertinoColors.systemBackground.resolveFrom(context),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  CupertinoButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Cancel'),
                  ),
                  CupertinoButton(
                    onPressed: () {
                      setState(() => _paperYear = temp);
                      Navigator.pop(ctx);
                    },
                    child: const Text('Done'),
                  ),
                ],
              ),
              Expanded(
                child: CupertinoPicker(
                  scrollController: controller,
                  itemExtent: 36,
                  onSelectedItemChanged: (i) => temp = years[i],
                  children: years
                      .map((y) => Center(child: Text('$y')))
                      .toList(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    controller.dispose();
  }

  String _guessContentType(String name) {
    switch (p.extension(name).toLowerCase()) {
      case '.pdf':
        return 'application/pdf';
      case '.png':
        return 'image/png';
      case '.jpg':
      case '.jpeg':
        return 'image/jpeg';
      default:
        return 'application/octet-stream';
    }
  }

  Future<void> _showUploadSourceSheet() async {
    await showCupertinoModalPopup<void>(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: const Text('Upload from'),
        message: const Text(
          'PDF or JPG/PNG. You can select multiple photos or files at once.',
        ),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () async {
              Navigator.of(ctx).pop();
              await _pickFromFiles();
            },
            child: const Text('Files'),
          ),
          CupertinoActionSheetAction(
            onPressed: () async {
              Navigator.of(ctx).pop();
              await _pickFromGallery();
            },
            child: const Text('Photo library'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          isDefaultAction: true,
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('Cancel'),
        ),
      ),
    );
  }

  Future<void> _pickFromFiles() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['pdf', 'png', 'jpg', 'jpeg'],
      withData: true,
      allowMultiple: true,
    );
    if (result == null || result.files.isEmpty) return;
    await _uploadPlatformFiles(result.files);
  }

  Future<void> _pickFromGallery() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: true,
      allowMultiple: true,
    );
    if (result == null || result.files.isEmpty) return;
    await _uploadPlatformFiles(result.files);
  }

  Future<void> _uploadPlatformFiles(List<PlatformFile> files) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    if (files.isEmpty) return;

    for (final f in files) {
      if (f.bytes == null) {
        showAcadexToast(
          context,
          'Could not read: ${f.name}. Try smaller files.',
          variant: AcadexToastVariant.neutral,
        );
        return;
      }
      var logicalName = f.name.isNotEmpty ? f.name : 'photo.jpg';
      var ext = p.extension(logicalName).toLowerCase();
      if (ext.isEmpty) {
        ext = '.jpg';
      }
      if (!isAllowedPaperFileExtension(ext)) {
        showAcadexToast(
          context,
          'Only PDF, PNG, JPEG. Not allowed: ${f.name}',
          variant: AcadexToastVariant.danger,
        );
        return;
      }
    }

    if (_schoolId == null ||
        _schoolName == null ||
        _schoolName!.trim().isEmpty ||
        _courseId == null ||
        _courseName == null ||
        _courseName!.trim().isEmpty) {
      showAcadexToast(
        context,
        'Please choose a school and a course code (pick existing or create new).',
        variant: AcadexToastVariant.neutral,
      );
      return;
    }
    if (!kPaperGrades.contains(_grade)) {
      showAcadexToast(
        context,
        'Please choose grade 9–12.',
        variant: AcadexToastVariant.neutral,
      );
      return;
    }
    if (!paperYearChoicesForUpload().contains(_paperYear)) {
      showAcadexToast(
        context,
        'Please choose a valid year.',
        variant: AcadexToastVariant.neutral,
      );
      return;
    }
    if (!kPaperSemesters.contains(_semester)) {
      showAcadexToast(
        context,
        'Please choose Semester 1 or Semester 2.',
        variant: AcadexToastVariant.neutral,
      );
      return;
    }

    final baseTitle = _titleController.text.trim();
    final batchId = files.length > 1 ? const Uuid().v4() : null;
    final insertedIds = <String>[];

    setState(() => _uploading = true);
    try {
      for (var i = 0; i < files.length; i++) {
        final f = files[i];
        final bytes = f.bytes!;
        var logicalName = f.name.isNotEmpty ? f.name : 'photo.jpg';
        var ext = p.extension(logicalName).toLowerCase();
        if (ext.isEmpty) {
          ext = '.jpg';
        }

        final title = files.length == 1
            ? (baseTitle.isNotEmpty
                ? baseTitle
                : p.basenameWithoutExtension(logicalName))
            : (baseTitle.isNotEmpty
                ? '$baseTitle (${i + 1})'
                : p.basenameWithoutExtension(logicalName));

        final objectPath = '${user.id}/${const Uuid().v4()}$ext';
        final contentType = _guessContentType(
          p.extension(logicalName).isNotEmpty ? logicalName : 'photo$ext',
        );

        await Supabase.instance.client.storage
            .from(kExamPapersBucket)
            .uploadBinary(
              objectPath,
              bytes,
              fileOptions: FileOptions(contentType: contentType),
            );

        final row = <String, dynamic>{
          'title': title,
          'storage_path': objectPath,
          'uploaded_by': user.id,
          'content_type': contentType,
          'school_id': _schoolId,
          'school_name': _schoolName!.trim(),
          'grade': _grade,
          'course_id': _courseId,
          'course_name': _courseName!.trim(),
          'paper_year': _paperYear,
          'semester': _semester,
        };
        final ver = _versionController.text.trim();
        if (ver.isNotEmpty) {
          row['paper_version'] = ver;
        }
        if (batchId != null) {
          row['upload_batch_id'] = batchId;
        }

        final ins = await Supabase.instance.client
            .from(kPapersTable)
            .insert(row)
            .select('id')
            .single();
        insertedIds.add(ins['id'] as String);
      }

      if (insertedIds.isNotEmpty) {
        final statRows = await Supabase.instance.client
            .from(kPapersTable)
            .select('approval_status')
            .inFilter('id', insertedIds);
        final list = statRows as List<dynamic>;
        if (list.length != insertedIds.length) {
          throw StateError('Could not verify upload status.');
        }
        final statuses = list
            .map((e) => (e as Map)['approval_status'] as String)
            .toList();
        final allApproved = statuses.every((s) => s == 'approved');
        final allPending = statuses.every((s) => s == 'pending');
        if (allPending) {
          await Supabase.instance.client.rpc(
            'notify_upload_pending_review',
            params: {'p_paper_ids': insertedIds},
          );
        }
        if (!mounted) return;
        _titleController.clear();
        await _refreshMyUploads();
        if (!mounted) return;
        if (allApproved) {
          showAcadexToast(
            context,
            files.length > 1 ? '${files.length} files published' : 'File published',
            variant: AcadexToastVariant.success,
          );
        } else if (allPending) {
          showAcadexToast(
            context,
            files.length > 1
                ? '${files.length} files submitted for review'
                : 'Submitted for review',
            variant: AcadexToastVariant.success,
          );
        } else {
          showAcadexToast(
            context,
            'Upload complete.',
            variant: AcadexToastVariant.success,
          );
        }
      } else {
        if (!mounted) return;
        _titleController.clear();
        await _refreshMyUploads();
        if (!mounted) return;
      }
    } catch (e) {
      if (!mounted) return;
      showAcadexToast(context, e.toString(), variant: AcadexToastVariant.danger);
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Widget _labeledRow(String label, String value, VoidCallback onTap) {
    final placeholder = value.startsWith('Tap to');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            color: CupertinoColors.secondaryLabel,
          ),
        ),
        const SizedBox(height: 6),
        CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: onTap,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: CupertinoColors.secondarySystemGroupedBackground
                  .resolveFrom(context),
              borderRadius: BorderRadius.circular(10),
            ),
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: TextStyle(
                fontSize: 17,
                color: placeholder
                    ? CupertinoColors.systemGrey.resolveFrom(context)
                    : CupertinoColors.label.resolveFrom(context),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _sectionHeader(
    String text, {
    double bottomSpacing = 8,
  }) {
    return Container(
      width: double.infinity,
      margin: EdgeInsets.only(bottom: bottomSpacing),
      padding: const EdgeInsets.only(top: 4),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.5,
        ),
      ),
    );
  }

  Widget _myUploadGroupTile(PaperListGroup group) {
    return Container(
      decoration: BoxDecoration(
        color: CupertinoColors.secondarySystemGroupedBackground
            .resolveFrom(context),
        borderRadius: BorderRadius.circular(12),
      ),
      clipBehavior: Clip.antiAlias,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: () {
                Navigator.of(context).push(
                  CupertinoPageRoute<void>(
                    builder: (context) => PaperDetailPage(paper: group.opener),
                  ),
                );
              },
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (group.opener.hasMetaDisplay) ...[
                      Text(
                        group.opener.metaDisplay,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: CupertinoColors.systemBlue,
                        ),
                      ),
                      const SizedBox(height: 6),
                    ],
                    Text(
                      group.listTitle,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        color: CupertinoColors.label.resolveFrom(context),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      group.latestCreatedAt.toLocal().toString(),
                      style: const TextStyle(
                        fontSize: 13,
                        color: CupertinoColors.secondaryLabel,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      group.count > 1
                          ? 'Tap to preview ${group.count} items'
                          : 'Tap to open',
                      style: const TextStyle(
                        fontSize: 12,
                        color: CupertinoColors.systemBlue,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      group.opener.approvalStatus == 'pending'
                          ? 'Pending review'
                          : 'Published',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: group.opener.approvalStatus == 'pending'
                            ? CupertinoColors.systemOrange.resolveFrom(context)
                            : CupertinoColors.secondaryLabel.resolveFrom(context),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          CupertinoButton(
            padding: const EdgeInsets.fromLTRB(4, 10, 10, 10),
            minimumSize: Size.zero,
            onPressed: () => _confirmDeleteGroup(group),
            child: Icon(
              CupertinoIcons.trash,
              color: CupertinoColors.destructiveRed.resolveFrom(context),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.systemGroupedBackground,
      navigationBar: CupertinoNavigationBar(
        middle: const Text('My Uploads'),
        border: null,
        trailing: _NavMailButton(hasUnread: widget.hasUnreadSystemMessages),
      ),
      child: SafeArea(
        child: Stack(
          children: [
            CustomScrollView(
              slivers: [
                CupertinoSliverRefreshControl(onRefresh: _onPullRefresh),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
                  sliver: SliverToBoxAdapter(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _sectionHeader(
                          'Your uploads',
                          bottomSpacing: 32,
                        ),
                        StreamBuilder<List<Map<String, dynamic>>>(
                          stream: _myUploadsStream,
                          builder: (context, snapshot) {
                            if (snapshot.hasError) {
                              return Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 16),
                                child: Text(
                                  snapshot.error.toString(),
                                  style: const TextStyle(
                                    color: CupertinoColors.destructiveRed,
                                  ),
                                ),
                              );
                            }
                            if (snapshot.connectionState ==
                                    ConnectionState.waiting &&
                                !snapshot.hasData) {
                              return const Padding(
                                padding: EdgeInsets.symmetric(vertical: 24),
                                child: Center(
                                  child: CupertinoActivityIndicator(),
                                ),
                              );
                            }
                            final rows = snapshot.data ?? [];
                            final papers = rows
                                .map(
                                  (e) => Paper.fromMap(
                                    Map<String, dynamic>.from(e),
                                  ),
                                )
                                .toList();
                            final groups = groupPapersForDisplay(papers);
                            if (groups.isEmpty) {
                              return const Text(
                                'Nothing uploaded yet.',
                                style: TextStyle(
                                  fontSize: 15,
                                  color: CupertinoColors.secondaryLabel,
                                ),
                              );
                            }
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                for (final g in groups) ...[
                                  _myUploadGroupTile(g),
                                  const SizedBox(height: 8),
                                ],
                              ],
                            );
                          },
                        ),
                        const SizedBox(height: 24),
                        _sectionHeader('Create new upload'),
                        const SizedBox(height: 8),
                        const Text(
                          'School & class',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Choose or create a school and course code, then grade, year, and semester.',
                          style: TextStyle(
                            fontSize: 13,
                            color: CupertinoColors.secondaryLabel,
                          ),
                        ),
                        const SizedBox(height: 14),
                        _labeledRow(
                          'School',
                          _schoolName ?? 'Tap to choose or create',
                          _pickSchool,
                        ),
                        const SizedBox(height: 12),
                        _labeledRow(
                          'Course code',
                          _courseName ?? 'Tap to choose or create',
                          _pickCourse,
                        ),
                        const SizedBox(height: 14),
                        const Text(
                          'Grade',
                          style: TextStyle(
                            fontSize: 13,
                            color: CupertinoColors.secondaryLabel,
                          ),
                        ),
                        const SizedBox(height: 8),
                        CupertinoSlidingSegmentedControl<int>(
                          groupValue: _grade,
                          children: {
                            for (final g in kPaperGrades)
                              g: Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 10),
                                child: Text('$g'),
                              ),
                          },
                          onValueChanged: (v) {
                            if (v != null) setState(() => _grade = v);
                          },
                        ),
                        const SizedBox(height: 14),
                        const Text(
                          'Year',
                          style: TextStyle(
                            fontSize: 13,
                            color: CupertinoColors.secondaryLabel,
                          ),
                        ),
                        const SizedBox(height: 6),
                        _labeledRow(
                          'Year',
                          '$_paperYear',
                          _pickUploadYear,
                        ),
                        const SizedBox(height: 14),
                        const Text(
                          'Semester',
                          style: TextStyle(
                            fontSize: 13,
                            color: CupertinoColors.secondaryLabel,
                          ),
                        ),
                        const SizedBox(height: 8),
                        CupertinoSlidingSegmentedControl<String>(
                          groupValue: _semester,
                          children: {
                            for (final s in kPaperSemesters)
                              s: Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 8,
                                  horizontal: 4,
                                ),
                                child: Text(
                                  s,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ),
                          },
                          onValueChanged: (v) {
                            if (v != null) setState(() => _semester = v);
                          },
                        ),
                        const SizedBox(height: 14),
                        const Text(
                          'Version (optional)',
                          style: TextStyle(
                            fontSize: 13,
                            color: CupertinoColors.secondaryLabel,
                          ),
                        ),
                        const SizedBox(height: 8),
                        CupertinoTextField(
                          controller: _versionController,
                          placeholder: 'e.g. morning',
                        ),
                        const SizedBox(height: 24),
                        const Text(
                          'Optional title (defaults to file name)',
                          style: TextStyle(
                            fontSize: 13,
                            color: CupertinoColors.secondaryLabel,
                          ),
                        ),
                        const SizedBox(height: 8),
                        CupertinoTextField(
                          controller: _titleController,
                          placeholder: 'Title',
                        ),
                        const SizedBox(height: 36),
                        CupertinoButton.filled(
                          onPressed:
                              _uploading ? null : _showUploadSourceSheet,
                          child: _uploading
                              ? const CupertinoActivityIndicator(
                                  color: CupertinoColors.white,
                                )
                              : const Text('Choose file & upload'),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            if (_deleteBusy)
              Positioned.fill(
                child: ColoredBox(
                  color: CupertinoColors.black.withValues(alpha: 0.18),
                  child: const Center(
                    child: CupertinoActivityIndicator(radius: 14),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ReviewUploadsTab extends StatefulWidget {
  const _ReviewUploadsTab({required this.hasUnreadSystemMessages});

  final bool hasUnreadSystemMessages;

  @override
  State<_ReviewUploadsTab> createState() => _ReviewUploadsTabState();
}

class _ReviewUploadsTabState extends State<_ReviewUploadsTab> {
  late Stream<List<Map<String, dynamic>>> _stream;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _stream = _createStream();
  }

  Stream<List<Map<String, dynamic>>> _createStream() {
    return Supabase.instance.client
        .from(kPapersTable)
        .stream(primaryKey: const ['id'])
        .eq('approval_status', 'pending')
        .order('created_at', ascending: false);
  }

  Future<void> _onRefresh() async {
    setState(() => _stream = _createStream());
    await Future<void>.delayed(const Duration(milliseconds: 400));
  }

  Future<void> _confirmReview(PaperListGroup group, bool approve) async {
    await showCupertinoDialog<void>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: Text(approve ? 'Approve upload?' : 'Reject upload?'),
        content: Text(
          approve
              ? 'This will make the file(s) visible to everyone in Papers.'
              : 'The file(s) will be deleted from storage and cannot be recovered.',
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: !approve,
            onPressed: () async {
              Navigator.of(ctx).pop();
              await _runReview(group, approve);
            },
            child: Text(approve ? 'Approve' : 'Reject'),
          ),
        ],
      ),
    );
  }

  Future<void> _runReview(PaperListGroup group, bool approve) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final ids = group.papers.map((p) => p.id).toList();
      await Supabase.instance.client.rpc(
        'review_paper_upload',
        params: {
          'p_paper_ids': ids,
          'p_approve': approve,
        },
      );
      if (!mounted) return;
      setState(() => _stream = _createStream());
      showAcadexToast(
        context,
        approve ? 'Upload approved' : 'Upload rejected',
        variant:
            approve ? AcadexToastVariant.success : AcadexToastVariant.neutral,
      );
    } catch (e) {
      if (mounted) {
        showAcadexToast(
          context,
          e.toString(),
          variant: AcadexToastVariant.danger,
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _reviewTile(PaperListGroup group) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: CupertinoColors.secondarySystemGroupedBackground.resolveFrom(
          context,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: CupertinoColors.separator.resolveFrom(context),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: () {
                Navigator.of(context).push(
                  CupertinoPageRoute<void>(
                    builder: (context) => PaperDetailPage(paper: group.opener),
                  ),
                );
              },
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (group.opener.hasMetaDisplay) ...[
                      Text(
                        group.opener.metaDisplay,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: CupertinoColors.systemBlue,
                        ),
                      ),
                      const SizedBox(height: 6),
                    ],
                    Text(
                      group.listTitle,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        color: CupertinoColors.label.resolveFrom(context),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      group.latestCreatedAt.toLocal().toString(),
                      style: const TextStyle(
                        fontSize: 13,
                        color: CupertinoColors.secondaryLabel,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Tap to preview',
                      style: TextStyle(
                        fontSize: 12,
                        color: CupertinoColors.systemBlue,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 6, bottom: 6),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CupertinoButton(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  minimumSize: Size.zero,
                  onPressed: _busy ? null : () => _confirmReview(group, true),
                  child: const Text(
                    'Approve',
                    style: TextStyle(
                      color: CupertinoColors.systemGreen,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                CupertinoButton(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  minimumSize: Size.zero,
                  onPressed: _busy ? null : () => _confirmReview(group, false),
                  child: Text(
                    'Reject',
                    style: TextStyle(
                      color: CupertinoColors.destructiveRed.resolveFrom(context),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.systemGroupedBackground,
      navigationBar: CupertinoNavigationBar(
        middle: const Text('Review Uploads'),
        border: null,
        trailing: _NavMailButton(hasUnread: widget.hasUnreadSystemMessages),
      ),
      child: SafeArea(
        child: Stack(
          children: [
            StreamBuilder<List<Map<String, dynamic>>>(
              stream: _stream,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        snapshot.error.toString(),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }
                if (!snapshot.hasData) {
                  return const Center(child: CupertinoActivityIndicator());
                }
                final rows = snapshot.data!;
                final papers = rows
                    .map(
                      (e) => Paper.fromMap(Map<String, dynamic>.from(e)),
                    )
                    .toList();
                final groups = groupPapersForDisplay(papers);
                if (groups.isEmpty) {
                  return CustomScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    slivers: [
                      CupertinoSliverRefreshControl(onRefresh: _onRefresh),
                      SliverFillRemaining(
                        child: Center(
                          child: Text(
                            'No pending uploads.',
                            style: TextStyle(
                              color: CupertinoColors.secondaryLabel
                                  .resolveFrom(context),
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                }
                return CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    CupertinoSliverRefreshControl(onRefresh: _onRefresh),
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, i) => _reviewTile(groups[i]),
                          childCount: groups.length,
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
            if (_busy)
              Positioned.fill(
                child: ColoredBox(
                  color: CupertinoColors.black.withValues(alpha: 0.12),
                  child: const Center(
                    child: CupertinoActivityIndicator(radius: 14),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _SystemMessagesTab extends StatefulWidget {
  const _SystemMessagesTab();

  @override
  State<_SystemMessagesTab> createState() => _SystemMessagesTabState();
}

class _SystemMessagesTabState extends State<_SystemMessagesTab> {
  late final String _userId;
  late Stream<List<Map<String, dynamic>>> _stream;
  bool _deleteBusy = false;

  @override
  void initState() {
    super.initState();
    _userId = Supabase.instance.client.auth.currentUser!.id;
    _stream = _createStream();
  }

  Future<void> _confirmDeleteMessage(String messageId) async {
    await showCupertinoDialog<void>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('Delete message?'),
        content: const Text('This will remove the message from your inbox.'),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () async {
              Navigator.of(ctx).pop();
              await _deleteMessage(messageId);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteMessage(String messageId) async {
    if (_deleteBusy || messageId.isEmpty) return;
    setState(() => _deleteBusy = true);
    try {
      await Supabase.instance.client.from(kSystemMessagesTable).delete().eq('id', messageId);
      if (mounted) {
        setState(() => _stream = _createStream());
        showAcadexToast(
          context,
          'Message deleted',
          variant: AcadexToastVariant.success,
        );
      }
    } catch (e) {
      if (mounted) {
        showAcadexToast(context, e.toString(), variant: AcadexToastVariant.danger);
      }
    } finally {
      if (mounted) setState(() => _deleteBusy = false);
    }
  }

  Future<void> _confirmDeleteAllMessages() async {
    await showCupertinoDialog<void>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('Delete all messages?'),
        content: const Text('This will remove every message from your inbox.'),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () async {
              Navigator.of(ctx).pop();
              await _deleteAllMessages();
            },
            child: const Text('Delete all'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteAllMessages() async {
    if (_deleteBusy) return;
    setState(() => _deleteBusy = true);
    try {
      await Supabase.instance.client.from(kSystemMessagesTable).delete().eq('user_id', _userId);
      if (mounted) {
        setState(() => _stream = _createStream());
        showAcadexToast(
          context,
          'All messages deleted',
          variant: AcadexToastVariant.success,
        );
      }
    } catch (e) {
      if (mounted) {
        showAcadexToast(context, e.toString(), variant: AcadexToastVariant.danger);
      }
    } finally {
      if (mounted) setState(() => _deleteBusy = false);
    }
  }

  Stream<List<Map<String, dynamic>>> _createStream() {
    return Supabase.instance.client
        .from(kSystemMessagesTable)
        .stream(primaryKey: const ['id'])
        .eq('user_id', _userId)
        .order('created_at', ascending: false);
  }

  Future<void> _onRefresh() async {
    setState(() => _stream = _createStream());
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.systemGroupedBackground,
      navigationBar: CupertinoNavigationBar(
        middle: const Text('System Messages'),
        border: null,
        trailing: CupertinoButton(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          minimumSize: Size.zero,
          onPressed: _deleteBusy ? null : _confirmDeleteAllMessages,
          child: Text(
            'Delete all',
            style: TextStyle(
              fontSize: 16,
              color: _deleteBusy
                  ? CupertinoColors.quaternaryLabel.resolveFrom(context)
                  : CupertinoColors.activeBlue.resolveFrom(context),
            ),
          ),
        ),
      ),
      child: SafeArea(
        child: StreamBuilder<List<Map<String, dynamic>>>(
          stream: _stream,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    'Could not load messages: ${snapshot.error}',
                    textAlign: TextAlign.center,
                  ),
                ),
              );
            }
            final list = snapshot.data;
            if (list == null) {
              return const Center(child: CupertinoActivityIndicator());
            }
            if (list.isEmpty) {
              return CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  CupertinoSliverRefreshControl(onRefresh: _onRefresh),
                  const SliverFillRemaining(
                    child: Center(
                      child: Text(
                        'No messages yet.',
                        style: TextStyle(color: CupertinoColors.secondaryLabel),
                      ),
                    ),
                  ),
                ],
              );
            }
            return CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                CupertinoSliverRefreshControl(onRefresh: _onRefresh),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                  sliver: SliverToBoxAdapter(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: CupertinoColors.separator.resolveFrom(context),
                        ),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            for (var i = 0; i < list.length; i++) ...[
                              if (i > 0)
                                Container(
                                  height: 1,
                                  color: CupertinoColors.separator.resolveFrom(context),
                                ),
                              _systemMessageInboxRow(
                                context,
                                list[i],
                                deleteBusy: _deleteBusy,
                                onDelete: () => _confirmDeleteMessage(
                                  list[i]['id'] as String? ?? '',
                                ),
                                onOpen: () {
                                  final r = list[i];
                                  Navigator.of(context).push(
                                    CupertinoPageRoute<void>(
                                      builder: (context) => _SystemMessageDetailPage(
                                        messageId: r['id'] as String? ?? '',
                                        title: r['title'] as String? ?? '',
                                        body: r['body'] as String? ?? '',
                                        createdAt: r['created_at'] as String? ?? '',
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _SystemMessageDetailPage extends StatefulWidget {
  const _SystemMessageDetailPage({
    required this.messageId,
    required this.title,
    required this.body,
    required this.createdAt,
  });

  final String messageId;
  final String title;
  final String body;
  final String createdAt;

  @override
  State<_SystemMessageDetailPage> createState() => _SystemMessageDetailPageState();
}

class _SystemMessageDetailPageState extends State<_SystemMessageDetailPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _markRead());
  }

  Future<void> _markRead() async {
    if (widget.messageId.isEmpty) return;
    try {
      await Supabase.instance.client.from(kSystemMessagesTable).update({
        'read_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', widget.messageId);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.systemGroupedBackground,
      navigationBar: CupertinoNavigationBar(
        border: null,
        middle: Text(
          widget.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              _formatSystemMessageTime(widget.createdAt),
              style: const TextStyle(
                fontSize: 13,
                color: CupertinoColors.secondaryLabel,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              widget.body,
              softWrap: true,
              style: const TextStyle(
                fontSize: 16,
                height: 1.4,
                color: CupertinoColors.label,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _UserTab extends StatefulWidget {
  const _UserTab({
    required this.isAdmin,
    required this.hasUnreadSystemMessages,
  });

  final bool isAdmin;
  final bool hasUnreadSystemMessages;

  @override
  State<_UserTab> createState() => _UserTabState();
}

class _UserTabState extends State<_UserTab> {
  String? _accountType;
  String? _username;
  bool _loadingProfile = true;

  Future<void> _editUsername() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    final controller = TextEditingController(text: _username ?? '');
    var secondConfirm = false;
    var busy = false;

    await showCupertinoDialog<void>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) => CupertinoAlertDialog(
            title: const Text('Edit username'),
            content: Column(
              children: [
                const SizedBox(height: 8),
                CupertinoTextField(
                  controller: controller,
                  placeholder: '3–32 letters, numbers, _',
                  autocorrect: false,
                ),
                const SizedBox(height: 8),
                Text(
                  secondConfirm
                      ? 'Tap confirm again to update username.'
                      : 'Username can contain letters, numbers, and underscores only.',
                  style: const TextStyle(
                    fontSize: 13,
                    color: CupertinoColors.secondaryLabel,
                  ),
                ),
              ],
            ),
            actions: [
              CupertinoDialogAction(
                onPressed: busy ? null : () => Navigator.of(ctx).pop(),
                child: const Text('Cancel'),
              ),
              CupertinoDialogAction(
                onPressed: busy
                    ? null
                    : () async {
                        final next = controller.text.trim();
                        if (!_usernamePattern.hasMatch(next)) {
                          showAcadexToast(
                            context,
                            'Username must be 3–32 characters: letters, numbers, and underscores only.',
                            variant: AcadexToastVariant.neutral,
                          );
                          return;
                        }
                        if (!secondConfirm) {
                          setDialogState(() => secondConfirm = true);
                          return;
                        }
                        setDialogState(() => busy = true);
                        try {
                          await Supabase.instance.client
                              .from(kPublicUsersTable)
                              .update({'username': next})
                              .eq('id', user.id);
                          if (!mounted) return;
                          setState(() => _username = next);
                          if (ctx.mounted) Navigator.of(ctx).pop();
                          showAcadexToast(
                            context,
                            'Username updated',
                            variant: AcadexToastVariant.success,
                          );
                        } catch (e) {
                          if (mounted) {
                            showAcadexToast(
                              context,
                              e.toString(),
                              variant: AcadexToastVariant.danger,
                            );
                          }
                        } finally {
                          if (mounted) {
                            setDialogState(() => busy = false);
                          }
                        }
                      },
                child: Text(
                  busy
                      ? 'Saving...'
                      : (secondConfirm ? 'Confirm Again' : 'Confirm'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      if (mounted) {
        setState(() {
          _loadingProfile = false;
          _accountType = null;
          _username = null;
        });
      }
      return;
    }
    try {
      final row = await Supabase.instance.client
          .from(kPublicUsersTable)
          .select('account_type, username')
          .eq('id', user.id)
          .maybeSingle();
      if (!mounted) return;
      setState(() {
        _accountType = row?['account_type'] as String?;
        _username = row?['username'] as String?;
        _loadingProfile = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _loadingProfile = false;
          _accountType = null;
          _username = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = Supabase.instance.client.auth.currentUser;
    final email = user?.email ?? '';
    final usernameLine = _loadingProfile ? '…' : (_username ?? '—');

    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.systemGroupedBackground,
      navigationBar: CupertinoNavigationBar(
        middle: const Text('User'),
        border: null,
        trailing: _NavMailButton(hasUnread: widget.hasUnreadSystemMessages),
      ),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text(
              'Username',
              style: TextStyle(
                fontSize: 13,
                color: CupertinoColors.secondaryLabel.resolveFrom(context),
              ),
            ),
            const SizedBox(height: 4),
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 6,
              runSpacing: 6,
              children: [
                Text(
                  usernameLine,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                CupertinoButton(
                  padding: EdgeInsets.zero,
                  minimumSize: Size.zero,
                  color: CupertinoColors.transparent,
                  borderRadius: BorderRadius.circular(4),
                  pressedOpacity: 0.55,
                  onPressed: _loadingProfile ? null : _editUsername,
                  child: Container(
                    width: 22,
                    height: 22,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: CupertinoColors.black,
                        width: 1,
                      ),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Icon(
                      CupertinoIcons.pencil,
                      size: 13,
                      color: CupertinoColors.black,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              email.isEmpty ? 'Not signed in' : email,
              style: const TextStyle(fontSize: 17),
            ),
            const SizedBox(height: 8),
            Text(
              _loadingProfile
                  ? 'Account type: …'
                  : 'Account type: ${displayAccountTypeLabel(_accountType)}',
              style: const TextStyle(
                fontSize: 15,
                color: CupertinoColors.secondaryLabel,
              ),
            ),
            if (widget.isAdmin) ...[
              const SizedBox(height: 16),
              CupertinoButton.filled(
                padding: const EdgeInsets.symmetric(vertical: 14),
                onPressed: () {
                  Navigator.of(context).push(
                    CupertinoPageRoute<void>(
                      builder: (context) => _UploadsTab(
                        hasUnreadSystemMessages:
                            widget.hasUnreadSystemMessages,
                      ),
                    ),
                  );
                },
                child: const Text('My uploads'),
              ),
            ],
            const SizedBox(height: 24),
            CupertinoButton.filled(
              onPressed: () async {
                await Supabase.instance.client.auth.signOut();
              },
              child: const Text('Sign out'),
            ),
          ],
        ),
      ),
    );
  }
}
