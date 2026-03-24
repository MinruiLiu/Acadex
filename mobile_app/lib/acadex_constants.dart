import 'package:path/path.dart' as p;

/// Must match `supabase/migrations/20250323120000_initial_papers.sql`.
const String kExamPapersBucket = 'exam-papers';
const String kPapersTable = 'papers';
const String kSchoolsTable = 'schools';
const String kCoursesTable = 'courses';

/// US high-school style grades supported for uploads.
const List<int> kPaperGrades = [9, 10, 11, 12];

/// Uploads: PDF and common raster images only (extension with or without dot).
const Set<String> kAllowedPaperExtensions = {'pdf', 'png', 'jpg', 'jpeg'};

bool isAllowedPaperFileExtension(String dottedOrPlain) {
  var e = dottedOrPlain.toLowerCase().trim();
  if (e.startsWith('.')) {
    e = e.substring(1);
  }
  return kAllowedPaperExtensions.contains(e);
}

bool paperStoragePathLooksLikePdf(String storagePath) {
  return p.extension(storagePath).toLowerCase() == '.pdf';
}

bool paperContentTypeIsPdf(String? contentType) {
  final t = contentType ?? '';
  return t.contains('pdf');
}

bool paperContentTypeIsImage(String? contentType) {
  return (contentType ?? '').toLowerCase().startsWith('image/');
}
