import 'package:path/path.dart' as p;

/// Must match `supabase/migrations/20250323120000_initial_papers.sql`.
const String kExamPapersBucket = 'exam-papers';
const String kPapersTable = 'papers';
const String kSchoolsTable = 'schools';
const String kCoursesTable = 'courses';
const String kPublicUsersTable = 'users';
const String kSystemMessagesTable = 'system_messages';

/// Maps stored [account_type] (free-form) to UI copy.
String displayAccountTypeLabel(String? raw) {
  switch (raw?.toLowerCase()) {
    case 'student':
      return 'Student account';
    case 'administrator':
      return 'Administrator account';
    default:
      if (raw == null || raw.isEmpty) {
        return 'Account';
      }
      return raw;
  }
}

/// US high-school style grades supported for uploads.
const List<int> kPaperGrades = [9, 10, 11, 12];

/// Must match DB check `papers_semester_check` and web `SEMESTERS`.
const List<String> kPaperSemesters = ['Semester 1', 'Semester 2'];

/// Descending years for upload / filters (e.g. 2000 … current+1).
List<int> paperYearChoicesForUpload() {
  final now = DateTime.now().year;
  final end = now + 1;
  const start = 2000;
  return [for (var y = end; y >= start; y--) y];
}

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
