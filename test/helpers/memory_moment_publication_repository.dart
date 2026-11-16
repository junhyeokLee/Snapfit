import 'package:flutter/material.dart';
import 'package:snap_fit/features/moments/data/moment_publication_repository.dart';
import 'package:snap_fit/features/moments/domain/moment_record.dart';
import 'package:snap_fit/features/social/domain/social_models.dart';

class MemoryMomentPublicationRepository implements MomentPublicationRepository {
  MemoryMomentPublicationRepository({this.recordRevision = 1});
  final int recordRevision;
  final states = <String, MomentPublicationState>{};
  final publications =
      <({MomentRecord record, String photoId, String requestId})>[];
  final privateCalls = <String>[];
  Object? publishError, privateError;
  Future<SocialWork> Function()? publishHandler;

  @override
  Future<MomentPublicationState?> state(String recordId) async =>
      states[recordId] ??
      MomentPublicationState(
        recordId: recordId,
        recordRevision: recordRevision,
        sourceRevision: recordRevision,
        status: 'private',
        publicationRevision: 0,
      );

  @override
  Future<SocialWork> publish({
    required MomentRecord record,
    required String photoId,
    required String requestId,
    required BuildContext context,
    required bool Function() canContinue,
  }) async {
    publications.add((record: record, photoId: photoId, requestId: requestId));
    if (publishError case final error?) throw error;
    if (publishHandler != null) return publishHandler!();
    states[record.id] = MomentPublicationState(
      recordId: record.id,
      recordRevision: record.revision,
      sourceRevision: record.revision,
      photoId: photoId,
      workId: 'moment-work',
      status: 'published',
      publicationRevision: 1,
    );
    return SocialWork(
      id: 'moment-work',
      author: const SocialProfile(
        userId: 'owner',
        displayName: '기록하는 사람',
        handle: 'memory',
      ),
      title: '오늘의 기록',
      kind: 'moment',
      createdAt: record.recordDate,
    );
  }

  @override
  Future<void> makePrivate(String recordId) async {
    privateCalls.add(recordId);
    if (privateError case final error?) throw error;
    final previous = await state(recordId);
    states[recordId] = MomentPublicationState(
      recordId: recordId,
      recordRevision: previous!.recordRevision,
      sourceRevision: previous.sourceRevision,
      photoId: previous.photoId,
      workId: previous.workId,
      status: 'private',
      publicationRevision: previous.publicationRevision + 1,
    );
  }

  @override
  void dispose() {}

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}
