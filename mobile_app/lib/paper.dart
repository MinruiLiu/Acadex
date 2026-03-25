class Paper {
  const Paper({
    required this.id,
    required this.createdAt,
    required this.title,
    required this.storagePath,
    required this.uploadedBy,
    this.contentType,
    this.uploadBatchId,
    this.schoolId,
    this.schoolName,
    this.grade,
    this.courseId,
    this.courseName,
    this.paperYear,
    this.semester,
    this.paperVersion,
    this.approvalStatus = 'approved',
  });

  final String id;
  final DateTime createdAt;
  final String title;
  final String storagePath;
  final String uploadedBy;
  final String? contentType;
  final String? uploadBatchId;
  final String? schoolId;
  final String? schoolName;
  final int? grade;
  final String? courseId;
  final String? courseName;
  final int? paperYear;
  final String? semester;
  final String? paperVersion;

  /// [pending] until an administrator approves; [approved] appears in Papers.
  final String approvalStatus;

  /// One line for list / preview: school, grade, course code, year, semester, version.
  String get metaDisplay {
    final parts = <String>[];
    if (schoolName != null && schoolName!.trim().isNotEmpty) {
      parts.add(schoolName!.trim());
    }
    if (grade != null) {
      parts.add('Grade $grade');
    }
    if (courseName != null && courseName!.trim().isNotEmpty) {
      parts.add(courseName!.trim());
    }
    if (paperYear != null) {
      parts.add('${paperYear!}');
    }
    if (semester != null && semester!.trim().isNotEmpty) {
      parts.add(semester!.trim());
    }
    if (paperVersion != null && paperVersion!.trim().isNotEmpty) {
      parts.add('Version ${paperVersion!.trim()}');
    }
    return parts.join(' · ');
  }

  bool get hasMetaDisplay => metaDisplay.isNotEmpty;

  factory Paper.fromMap(Map<String, dynamic> row) {
    return Paper(
      id: row['id'] as String,
      createdAt: DateTime.parse(row['created_at'] as String),
      title: row['title'] as String,
      storagePath: row['storage_path'] as String,
      uploadedBy: row['uploaded_by'] as String,
      contentType: row['content_type'] as String?,
      uploadBatchId: row['upload_batch_id'] as String?,
      schoolId: row['school_id'] as String?,
      schoolName: row['school_name'] as String?,
      grade: (row['grade'] as num?)?.toInt(),
      courseId: row['course_id'] as String?,
      courseName: row['course_name'] as String?,
      paperYear: (row['paper_year'] as num?)?.toInt(),
      semester: row['semester'] as String?,
      paperVersion: row['paper_version'] as String?,
      approvalStatus: (row['approval_status'] as String?) ?? 'approved',
    );
  }
}
