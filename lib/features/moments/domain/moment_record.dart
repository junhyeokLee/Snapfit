import 'moment_photo_design.dart';

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
    this.design,
  });
  final String id, path, url;
  final int width, height;
  final MomentPhotoDesign? design;
  String get storageUri => 'supabase://album-assets/$path';
  double get aspectRatio => design?.aspectRatio ?? width / height;

  factory MomentPhoto.fromJson(Map<String, dynamic> json) => MomentPhoto(
    id: json['id'] as String,
    path: json['path'] as String,
    width: (json['width'] as num).toInt(),
    height: (json['height'] as num).toInt(),
    design: json['design'] == null
        ? null
        : MomentPhotoDesign.fromJson(
            Map<String, dynamic>.from(json['design'] as Map),
          ),
  );

  MomentPhoto withUrl(String value) => MomentPhoto(
    id: id,
    path: path,
    url: value,
    width: width,
    height: height,
    design: design,
  );

  MomentPhoto withDesign(MomentPhotoDesign? value) => MomentPhoto(
    id: id,
    path: path,
    url: url,
    width: width,
    height: height,
    design: value,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'path': path,
    'width': width,
    'height': height,
    if (design != null) 'design': design!.toJson(),
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

/// 서버에서 검증한 당일 사진 기록만 월간 완주 일수로 인정한다.
class MomentMonthlyReward {
  const MomentMonthlyReward({
    required this.points,
    required this.recordedDays,
    required this.daysInMonth,
    required this.awarded,
    required this.canComplete,
    this.awardedAt,
  });

  final int points, recordedDays, daysInMonth;
  final bool awarded, canComplete;
  final DateTime? awardedAt;

  factory MomentMonthlyReward.fromJson(Map<String, dynamic> json) {
    final points = json['points'];
    final recordedDays = json['recordedDays'];
    final daysInMonth = json['daysInMonth'];
    final awarded = json['awarded'];
    final canComplete = json['canComplete'];
    final rawAwardedAt = json['awardedAt'];
    final awardedAt = rawAwardedAt is String
        ? DateTime.tryParse(rawAwardedAt)
        : null;
    if (points is! int ||
        points <= 0 ||
        daysInMonth is! int ||
        daysInMonth < 28 ||
        daysInMonth > 31 ||
        recordedDays is! int ||
        recordedDays < 0 ||
        recordedDays > daysInMonth ||
        awarded is! bool ||
        canComplete is! bool ||
        (rawAwardedAt != null && awardedAt == null)) {
      throw const FormatException('월간 기록 보상 정보를 확인하지 못했어요.');
    }
    return MomentMonthlyReward(
      points: points,
      recordedDays: recordedDays,
      daysInMonth: daysInMonth,
      awarded: awarded,
      canComplete: canComplete,
      awardedAt: awardedAt,
    );
  }
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
    this.monthlyReward,
  });
  final DateTime today, weekStart, month;
  final List<MomentRecord> records;
  final int weekPhotoCount;
  final int? monthlyAlbumId;
  final List<MomentRecord>? weekRecords;
  final List<String> monthlyAlbumPhotoIds;
  final MomentMonthlyReward? monthlyReward;

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
    monthlyReward: json['monthlyReward'] == null
        ? null
        : MomentMonthlyReward.fromJson(
            Map<String, dynamic>.from(json['monthlyReward'] as Map),
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
    monthlyReward: monthlyReward,
  );
}
