import 'paper.dart';

/// One row in the Papers list: either a single paper or a whole multi-upload batch.
class PaperListGroup {
  PaperListGroup({required this.papers}) : assert(papers.isNotEmpty);

  final List<Paper> papers;

  /// Opens [PaperDetailPage] with this; detail loads the full batch via `upload_batch_id`.
  Paper get opener => papers.first;

  DateTime get latestCreatedAt {
    return papers
        .map((p) => p.createdAt)
        .reduce((a, b) => a.isAfter(b) ? a : b);
  }

  /// Title for the list cell (one line per batch in the UI).
  String get listTitle {
    if (papers.length == 1) {
      return papers.single.title;
    }
    final first = papers.first.title;
    final m = RegExp(r'^(.*) \(\d+\)$').firstMatch(first);
    final base = m != null ? m.group(1)!.trim() : first;
    return '$base (${papers.length} files)';
  }

  int get count => papers.length;
}

/// Merges rows that share `upload_batch_id` into a single [PaperListGroup].
List<PaperListGroup> groupPapersForDisplay(List<Paper> papers) {
  final byBatch = <String, List<Paper>>{};
  final singles = <Paper>[];

  for (final p in papers) {
    final bid = p.uploadBatchId;
    if (bid != null && bid.isNotEmpty) {
      byBatch.putIfAbsent(bid, () => []).add(p);
    } else {
      singles.add(p);
    }
  }

  final groups = <PaperListGroup>[];
  for (final list in byBatch.values) {
    list.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    groups.add(PaperListGroup(papers: list));
  }
  for (final p in singles) {
    groups.add(PaperListGroup(papers: [p]));
  }

  groups.sort((a, b) => b.latestCreatedAt.compareTo(a.latestCreatedAt));
  return groups;
}
