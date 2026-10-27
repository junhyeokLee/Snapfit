/// Calendar dates in the journal use UTC values as date-only containers. The
/// server defines today in Asia/Seoul; no device timezone converts stored dates.
DateTime momentDate(DateTime value) =>
    DateTime.utc(value.year, value.month, value.day);

DateTime momentMonth(DateTime value) => DateTime.utc(value.year, value.month);

DateTime momentToday([DateTime? now]) =>
    momentDate((now ?? DateTime.now()).toUtc().add(const Duration(hours: 9)));

DateTime momentWeekStart(DateTime date) =>
    momentDate(date).subtract(Duration(days: date.weekday - DateTime.monday));

String momentDateKey(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

class MomentException implements Exception {
  const MomentException(this.message);
  final String message;
  @override
  String toString() => message;
}

class MomentPhoto {
  const MomentPhoto({
    required this.id,
    required this.path,
    this.url = '',
    required this.width,
    required this.height,
  });
  final String id, path, url;
  final int width, height;
  String get storageUri => 'supabase://album-assets/$path';

  factory MomentPhoto.fromJson(Map<String, dynamic> json) => MomentPhoto(
    id: json['id'] as String,
    path: json['path'] as String,
    width: (json['width'] as num).toInt(),
    height: (json['height'] as num).toInt(),
  );

  MomentPhoto withUrl(String value) =>
      MomentPhoto(id: id, path: path, url: value, width: width, height: height);

  Map<String, dynamic> toJson() => {
    'id': id,
    'path': path,
    'width': width,
    'height': height,
  };
}

class MomentRecord {
  const MomentRecord({
    required this.id,
    required this.recordDate,
    required this.caption,
    required this.photos,
    required this.revision,
  });
  final String id, caption;
  final DateTime recordDate;
  final List<MomentPhoto> photos;
  final int revision;

  factory MomentRecord.fromJson(Map<String, dynamic> json) => MomentRecord(
    id: json['id'] as String,
    recordDate: momentDate(DateTime.parse(json['record_date'] as String)),
    caption: json['caption'] as String? ?? '',
    photos: List.unmodifiable(
      (json['photos'] as List).map(
        (value) =>
            MomentPhoto.fromJson(Map<String, dynamic>.from(value as Map)),
      ),
    ),
    revision: (json['revision'] as num).toInt(),
  );

  MomentRecord withPhotos(List<MomentPhoto> value) => MomentRecord(
    id: id,
    recordDate: recordDate,
    caption: caption,
    photos: List.unmodifiable(value),
    revision: revision,
  );
}

class MomentJournal {
  const MomentJournal({
    required this.today,
    required this.weekStart,
    required this.month,
    required this.records,
    required this.weekPhotoCount,
    this.monthlyAlbumId,
    this.weekRecords,
    this.monthlyAlbumPhotoIds = const [],
  });
  final DateTime today, weekStart, month;
  final List<MomentRecord> records;
  final int weekPhotoCount;
  final int? monthlyAlbumId;
  final List<MomentRecord>? weekRecords;
  final List<String> monthlyAlbumPhotoIds;

  /// The server includes the entire current week even across month boundaries.
  List<MomentRecord> get currentWeekRecords =>
      weekRecords ??
      records
          .where(
            (record) =>
                !record.recordDate.isBefore(weekStart) &&
                record.recordDate.isBefore(
                  weekStart.add(const Duration(days: 7)),
                ),
          )
          .toList(growable: false);

  factory MomentJournal.fromJson(Map<String, dynamic> json) => MomentJournal(
    today: momentDate(DateTime.parse(json['today'] as String)),
    weekStart: momentDate(DateTime.parse(json['weekStart'] as String)),
    month: momentMonth(DateTime.parse(json['month'] as String)),
    records: List.unmodifiable(
      (json['records'] as List).map(
        (value) =>
            MomentRecord.fromJson(Map<String, dynamic>.from(value as Map)),
      ),
    ),
    weekPhotoCount: (json['weekPhotoCount'] as num).toInt(),
    monthlyAlbumId: (json['monthlyAlbumId'] as num?)?.toInt(),
    weekRecords: (json['weekRecords'] as List?)
        ?.map(
          (value) =>
              MomentRecord.fromJson(Map<String, dynamic>.from(value as Map)),
        )
        .toList(growable: false),
    monthlyAlbumPhotoIds: List<String>.unmodifiable(
      (json['monthlyAlbumPhotoIds'] as List? ?? const []).cast<String>(),
    ),
  );

  MomentJournal withRecords(List<MomentRecord> value) => MomentJournal(
    today: today,
    weekStart: weekStart,
    month: month,
    records: List.unmodifiable(value),
    weekPhotoCount: weekPhotoCount,
    monthlyAlbumId: monthlyAlbumId,
    weekRecords: weekRecords,
    monthlyAlbumPhotoIds: monthlyAlbumPhotoIds,
  );
}
