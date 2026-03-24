import 'package:file_picker/file_picker.dart';
import 'package:flutter/cupertino.dart';
import 'package:path/path.dart' as p;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import 'acadex_constants.dart';
import 'catalog_picker_sheet.dart';
import 'paper.dart';
import 'paper_detail_page.dart';
import 'paper_list_group.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  @override
  Widget build(BuildContext context) {
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
            icon: _tabIcon(CupertinoIcons.tray_arrow_up),
            activeIcon: _tabIcon(CupertinoIcons.tray_arrow_up_fill),
            label: 'My Uploads',
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
            return const _PapersTab();
          case 1:
            return const _UploadsTab();
          default:
            return const _UserTab();
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

class _PapersTab extends StatefulWidget {
  const _PapersTab();

  @override
  State<_PapersTab> createState() => _PapersTabState();
}

class _PapersTabState extends State<_PapersTab> {
  /// New instance on pull-to-refresh so the list reloads from PostgREST + Realtime.
  late Stream<List<Map<String, dynamic>>> _papersStream;

  @override
  void initState() {
    super.initState();
    _papersStream = _createPapersStream();
  }

  Stream<List<Map<String, dynamic>>> _createPapersStream() {
    return Supabase.instance.client
        .from(kPapersTable)
        .stream(primaryKey: const ['id'])
        .order('created_at', ascending: false);
  }

  Future<void> _onRefresh() async {
    setState(() {
      _papersStream = _createPapersStream();
    });
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.systemGroupedBackground,
      navigationBar: CupertinoNavigationBar(
        middle: const Text('Papers'),
        border: null,
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: _onRefresh,
          child: const Icon(CupertinoIcons.arrow_clockwise),
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
            final papers = rows
                .map((e) => Paper.fromMap(Map<String, dynamic>.from(e)))
                .toList();
            final groups = groupPapersForDisplay(papers);
            if (groups.isEmpty) {
              return CustomScrollView(
                slivers: [
                  CupertinoSliverRefreshControl(onRefresh: _onRefresh),
                  const SliverFillRemaining(
                    child: Center(
                      child: Text('No papers yet. Upload one in My Uploads.'),
                    ),
                  ),
                ],
              );
            }
            return CustomScrollView(
              slivers: [
                CupertinoSliverRefreshControl(onRefresh: _onRefresh),
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
                            child: Container(
                              width: double.infinity,
                              alignment: Alignment.centerLeft,
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: CupertinoColors
                                    .secondarySystemGroupedBackground
                                    .resolveFrom(context),
                                borderRadius: BorderRadius.circular(12),
                              ),
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
                                      color:
                                          CupertinoColors.label.resolveFrom(context),
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
                                ],
                              ),
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
  const _UploadsTab();

  @override
  State<_UploadsTab> createState() => _UploadsTabState();
}

class _UploadsTabState extends State<_UploadsTab> {
  final _titleController = TextEditingController();
  bool _uploading = false;

  List<Map<String, dynamic>> _schoolRows = [];
  List<Map<String, dynamic>> _courseRows = [];
  String? _schoolId;
  String? _schoolName;
  String? _courseId;
  String? _courseName;
  int _grade = 10;

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
    } catch (e) {
      if (mounted) _alert(e.toString());
    } finally {
      if (mounted) setState(() => _deleteBusy = false);
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
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
      title: 'Course',
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
        _alert('Could not read: ${f.name}. Try smaller files.');
        return;
      }
      var logicalName = f.name.isNotEmpty ? f.name : 'photo.jpg';
      var ext = p.extension(logicalName).toLowerCase();
      if (ext.isEmpty) {
        ext = '.jpg';
      }
      if (!isAllowedPaperFileExtension(ext)) {
        _alert('Only PDF, PNG, JPEG. Not allowed: ${f.name}');
        return;
      }
    }

    if (_schoolId == null ||
        _schoolName == null ||
        _schoolName!.trim().isEmpty ||
        _courseId == null ||
        _courseName == null ||
        _courseName!.trim().isEmpty) {
      _alert(
        'Please choose a school and a course (pick existing or create new).',
      );
      return;
    }
    if (!kPaperGrades.contains(_grade)) {
      _alert('Please choose grade 9–12.');
      return;
    }

    final baseTitle = _titleController.text.trim();
    final batchId = files.length > 1 ? const Uuid().v4() : null;

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
        };
        if (batchId != null) {
          row['upload_batch_id'] = batchId;
        }

        await Supabase.instance.client.from(kPapersTable).insert(row);
      }

      if (!mounted) return;
      _titleController.clear();
      await _refreshMyUploads();
      if (!mounted) return;
      showCupertinoDialog<void>(
        context: context,
        builder: (ctx) => CupertinoAlertDialog(
          title: const Text('Uploaded'),
          content: Text(
            files.length == 1
                ? 'Your file is on the server.'
                : '${files.length} files uploaded.',
          ),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      _alert(e.toString());
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

  void _alert(String message) {
    showCupertinoDialog<void>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('Upload'),
        content: Text(message),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Widget _sectionHeader(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, top: 4),
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
      navigationBar: const CupertinoNavigationBar(
        middle: Text('My Uploads'),
        border: null,
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
                        _sectionHeader('Your uploads'),
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
                              return const Padding(
                                padding: EdgeInsets.symmetric(vertical: 12),
                                child: Text(
                                  'Nothing uploaded yet.',
                                  style: TextStyle(
                                    fontSize: 15,
                                    color: CupertinoColors.secondaryLabel,
                                  ),
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
                          'Choose or create a school and course, then pick grade 9–12.',
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
                          'Course',
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
                        const SizedBox(height: 20),
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

class _UserTab extends StatelessWidget {
  const _UserTab();

  @override
  Widget build(BuildContext context) {
    final user = Supabase.instance.client.auth.currentUser;
    final email = user?.email ?? '';

    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.systemGroupedBackground,
      navigationBar: const CupertinoNavigationBar(
        middle: Text('User'),
        border: null,
      ),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text(
              email.isEmpty ? 'Not signed in' : email,
              style: const TextStyle(fontSize: 17),
            ),
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
