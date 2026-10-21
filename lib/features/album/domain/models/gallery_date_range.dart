/// Inclusive calendar dates for browsing the device photo library.
///
/// Build the next local midnight from its calendar fields rather than adding
/// 24 hours: a daylight-saving day can have a different length.
class GalleryDateRange {
  factory GalleryDateRange(DateTime start, DateTime end) {
    final startDate = DateTime(start.year, start.month, start.day);
    final endDate = DateTime(end.year, end.month, end.day);
    if (endDate.isBefore(startDate)) {
      throw ArgumentError('종료 날짜는 시작 날짜보다 빠를 수 없습니다.');
    }
    return GalleryDateRange._(startDate, endDate);
  }

  const GalleryDateRange._(this.start, this.end);

  final DateTime start;
  final DateTime end;

  DateTime get endExclusive => DateTime(end.year, end.month, end.day + 1);
  DateTime get lastInstant =>
      endExclusive.subtract(const Duration(milliseconds: 1));

  @override
  bool operator ==(Object other) =>
      other is GalleryDateRange && start == other.start && end == other.end;

  @override
  int get hashCode => Object.hash(start, end);
}
