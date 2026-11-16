import 'moment_record.dart';

/// Owner-only month metadata. Original records/photos remain in the journal.
class MomentMonthSummary {
  const MomentMonthSummary({
    required this.month,
    required this.recordCount,
    required this.photoCount,
    this.coverPhoto,
    this.latestRecordDate,
  });
  final DateTime month;
  final int recordCount, photoCount;
  final MomentPhoto? coverPhoto;
  final DateTime? latestRecordDate;

  factory MomentMonthSummary.fromJson(Map<String, dynamic> json) =>
      MomentMonthSummary(
        month: momentMonth(DateTime.parse(json['month'] as String)),
        recordCount: (json['recordCount'] as num).toInt(),
        photoCount: (json['photoCount'] as num).toInt(),
        coverPhoto: json['coverPhoto'] == null
            ? null
            : MomentPhoto.fromJson(
                Map<String, dynamic>.from(json['coverPhoto'] as Map),
              ),
        latestRecordDate: json['latestRecordDate'] == null
            ? null
            : momentDate(DateTime.parse(json['latestRecordDate'] as String)),
      );
}

class PrivateMomentMonthsQuery {
  const PrivateMomentMonthsQuery(
    this.ownerId, {
    this.beforeMonth,
    this.limit = 6,
  });
  final String ownerId;
  final DateTime? beforeMonth;
  final int limit;
  String? get _cursor =>
      beforeMonth == null ? null : momentDateKey(momentMonth(beforeMonth!));
  @override
  bool operator ==(Object other) =>
      other is PrivateMomentMonthsQuery &&
      ownerId == other.ownerId &&
      _cursor == other._cursor &&
      limit == other.limit;
  @override
  int get hashCode => Object.hash(ownerId, _cursor, limit);
}

class MomentPhotoChoicesQuery {
  const MomentPhotoChoicesQuery(this.ownerId, this.month);
  final String ownerId;
  final DateTime month;
  String get _month => momentDateKey(momentMonth(month));
  @override
  bool operator ==(Object other) =>
      other is MomentPhotoChoicesQuery &&
      ownerId == other.ownerId &&
      _month == other._month;
  @override
  int get hashCode => Object.hash(ownerId, _month);
}

class MomentWeeklyChoicesQuery {
  const MomentWeeklyChoicesQuery(this.ownerId, this.weekStart);
  final String ownerId;
  final DateTime weekStart;
  String get _week => momentDateKey(momentDate(weekStart));
  @override
  bool operator ==(Object other) =>
      other is MomentWeeklyChoicesQuery &&
      ownerId == other.ownerId &&
      _week == other._week;
  @override
  int get hashCode => Object.hash(ownerId, _week);
}
