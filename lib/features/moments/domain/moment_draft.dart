import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

import 'moment_record.dart';
import 'moment_photo_design.dart';

/// An unsubmitted record kept only on this device, under its signed-in owner.
class MomentDraft {
  MomentDraft({
    required this.ownerId,
    required this.recordId,
    required DateTime recordDate,
    required this.caption,
    required List<MomentPhoto> existingPhotos,
    required List<MomentDraftUpload> uploads,
    required this.updatedAt,
    this.originalRecord,
    this.version,
    this.pendingSaveFingerprint,
  }) : recordDate = momentDate(recordDate),
       existingPhotos = List.unmodifiable(existingPhotos),
       uploads = List.unmodifiable(uploads);

  final String ownerId, recordId, caption;
  final DateTime recordDate, updatedAt;
  final List<MomentPhoto> existingPhotos;
  final List<MomentDraftUpload> uploads;
  final MomentRecord? originalRecord;
  final String? pendingSaveFingerprint;

  /// 날짜가 지난 뒤에는 실제 전송했던 동일 요청만 서버에 재확인한다.
  String get saveFingerprint => sha256
      .convert(
        utf8.encode(
          jsonEncode({
            'ownerId': ownerId,
            'recordId': recordId,
            'recordDate': momentDateKey(recordDate),
            'caption': caption.trim(),
            'photos': existingPhotos.map((photo) => photo.toJson()).toList(),
            'uploads': uploads
                .map(
                  (upload) => {
                    'id': upload.id,
                    'bytes': sha256.convert(upload.bytes).toString(),
                    'design': upload.design?.toJson(),
                  },
                )
                .toList(),
            'expectedRevision': originalRecord?.revision ?? 0,
          }),
        ),
      )
      .toString();

  bool get hasPendingSave =>
      pendingSaveFingerprint != null &&
      pendingSaveFingerprint == saveFingerprint;

  /// An opaque compare-and-swap token assigned only after a durable write.
  final String? version;

  bool get isEditing => originalRecord != null;
  bool get hasContent =>
      caption.trim().isNotEmpty ||
      existingPhotos.isNotEmpty ||
      uploads.isNotEmpty;

  MomentDraft copyWith({
    DateTime? recordDate,
    String? caption,
    List<MomentPhoto>? existingPhotos,
    List<MomentDraftUpload>? uploads,
    DateTime? updatedAt,
    String? version,
    String? pendingSaveFingerprint,
  }) => MomentDraft(
    ownerId: ownerId,
    recordId: recordId,
    recordDate: recordDate ?? this.recordDate,
    caption: caption ?? this.caption,
    existingPhotos: existingPhotos ?? this.existingPhotos,
    uploads: uploads ?? this.uploads,
    updatedAt: updatedAt ?? this.updatedAt,
    originalRecord: originalRecord,
    version: version ?? this.version,
    pendingSaveFingerprint:
        pendingSaveFingerprint ??
        (recordDate != null ||
                caption != null ||
                existingPhotos != null ||
                uploads != null
            ? null
            : this.pendingSaveFingerprint),
  );

  /// Photo bytes are stored separately from JSON. Signed URLs are not retained.
  Map<String, dynamic> toMetadata() => {
    'schema': 1,
    'ownerId': ownerId,
    'recordId': recordId,
    'recordDate': momentDateKey(recordDate),
    'caption': caption,
    'existingPhotos': existingPhotos.map((photo) => photo.toJson()).toList(),
    'uploads': uploads
        .map(
          (photo) => {
            'id': photo.id,
            'filename': photo.filename,
            'length': photo.bytes.length,
            if (photo.design != null) 'design': photo.design!.toJson(),
          },
        )
        .toList(),
    'updatedAt': updatedAt.toUtc().toIso8601String(),
    'version': version,
    if (pendingSaveFingerprint != null)
      'pendingSaveFingerprint': pendingSaveFingerprint,
    if (originalRecord case final original?)
      'originalRecord': {
        'id': original.id,
        'record_date': momentDateKey(original.recordDate),
        'caption': original.caption,
        'photos': original.photos.map((photo) => photo.toJson()).toList(),
        'revision': original.revision,
      },
  };

  factory MomentDraft.fromMetadata(
    Map<String, dynamic> json, {
    required List<Uint8List> photoBytes,
  }) {
    if (json['schema'] != 1)
      throw const FormatException('Unknown moment draft');
    final uploads = json['uploads'] as List;
    if (uploads.length != photoBytes.length) {
      throw const FormatException('Missing moment draft photos');
    }
    final pendingSaveFingerprint = json['pendingSaveFingerprint'];
    if (pendingSaveFingerprint != null &&
        (pendingSaveFingerprint is! String ||
            !RegExp(r'^[0-9a-f]{64}$').hasMatch(pendingSaveFingerprint))) {
      throw const FormatException('Invalid pending moment save');
    }
    return MomentDraft(
      ownerId: json['ownerId'] as String,
      recordId: json['recordId'] as String,
      recordDate: DateTime.parse(json['recordDate'] as String),
      caption: json['caption'] as String,
      existingPhotos: (json['existingPhotos'] as List)
          .map(
            (value) =>
                MomentPhoto.fromJson(Map<String, dynamic>.from(value as Map)),
          )
          .toList(),
      uploads: List.generate(uploads.length, (index) {
        final upload = Map<String, dynamic>.from(uploads[index] as Map);
        if (upload['length'] != photoBytes[index].length) {
          throw const FormatException('Incomplete moment draft photo');
        }
        return MomentDraftUpload(
          id: upload['id'] as String,
          filename: upload['filename'] as String,
          bytes: photoBytes[index],
          design: upload['design'] == null
              ? null
              : MomentPhotoDesign.fromJson(
                  Map<String, dynamic>.from(upload['design'] as Map),
                ),
        );
      }),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      originalRecord: json['originalRecord'] == null
          ? null
          : MomentRecord.fromJson(
              Map<String, dynamic>.from(json['originalRecord'] as Map),
            ),
      version: json['version'] as String?,
      pendingSaveFingerprint: pendingSaveFingerprint as String?,
    );
  }
}

class MomentDraftUpload {
  MomentDraftUpload({
    required this.id,
    required this.filename,
    required Uint8List bytes,
    this.design,
  }) : bytes = Uint8List.fromList(bytes).asUnmodifiableView();

  final String id, filename;
  final Uint8List bytes;
  final MomentPhotoDesign? design;

  MomentDraftUpload withDesign(MomentPhotoDesign? value) => MomentDraftUpload(
    id: id,
    filename: filename,
    bytes: bytes,
    design: value,
  );
}

/// Small account-scoped recovery information; this never loads photo originals.
class MomentDraftSummary {
  const MomentDraftSummary({
    required this.ownerId,
    required this.recordId,
    required this.recordDate,
    required this.caption,
    required this.updatedAt,
    required this.version,
    required this.isEditing,
    required this.photoCount,
    required this.photoBytes,
  });
  final String ownerId, recordId, caption, version;
  final DateTime recordDate, updatedAt;
  final bool isEditing;
  final int photoCount, photoBytes;
  bool get hasContent => caption.trim().isNotEmpty || photoCount > 0;

  factory MomentDraftSummary.fromMetadata(Map<String, dynamic> json) {
    if (json['schema'] != 1)
      throw const FormatException('Unknown moment draft');
    final uploads = json['uploads'] as List;
    final existing = json['existingPhotos'] as List;
    var bytes = 0;
    for (final upload in uploads) {
      final length = (upload as Map)['length'];
      if (length is! int || length <= 0 || length > 20 * 1024 * 1024) {
        throw const FormatException('Invalid draft photo length');
      }
      bytes += length;
    }
    final owner = json['ownerId'] as String;
    final id = json['recordId'] as String;
    final version = json['version'] as String;
    final caption = json['caption'] as String;
    final dateString = json['recordDate'] as String;
    final date = DateTime.parse(dateString);
    if (owner.trim().isEmpty ||
        owner.length > 256 ||
        id.trim().isEmpty ||
        id.length > 256 ||
        version.isEmpty ||
        caption.length > 2000 ||
        existing.length + uploads.length > 3 ||
        momentDateKey(date) != dateString) {
      throw const FormatException('Invalid moment draft identity');
    }
    return MomentDraftSummary(
      ownerId: owner,
      recordId: id,
      recordDate: momentDate(date),
      caption: caption,
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      version: version,
      isEditing: json['originalRecord'] != null,
      photoCount: existing.length + uploads.length,
      photoBytes: bytes,
    );
  }
}
