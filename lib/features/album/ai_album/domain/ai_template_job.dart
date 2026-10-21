import 'dart:async';
import 'ai_album_models.dart';

enum AiTemplateJobState {
  queued,
  running,
  waiting,
  ready,
  failed,
  canceled,
  expired,
  consumed,
}

class AiTemplateJob {
  const AiTemplateJob({
    required this.id,
    required this.state,
    required this.stage,
    required this.completedStages,
    required this.brief,
    this.nextAttemptAt,
    this.expiresAt,
    this.error,
    this.draft,
    this.alreadyAccepted = false,
    required this.envelope,
  });
  final String id, stage;
  final AiTemplateJobState state;
  final int completedStages;
  final AiTemplateBrief brief;
  final DateTime? nextAttemptAt, expiresAt;
  final String? error;
  final AlbumRecommendationDraft? draft;
  final bool alreadyAccepted;
  final Map<String, Object?> envelope;
  bool get pending => const [
    AiTemplateJobState.queued,
    AiTemplateJobState.running,
    AiTemplateJobState.waiting,
  ].contains(state);
  bool get usable =>
      (state == AiTemplateJobState.ready ||
          (state == AiTemplateJobState.consumed && alreadyAccepted)) &&
      draft != null;
}

/// A deferred free-tier request needs no frequent foreground status traffic.
Duration aiTemplateJobPollDelay(AiTemplateJob job, DateTime now) {
  final until = job.nextAttemptAt?.difference(now).inSeconds ?? 15;
  final maximum = job.state == AiTemplateJobState.waiting ? 3600 : 60;
  return Duration(seconds: until.clamp(15, maximum));
}

class AiTemplatePollingToken {
  bool canceled = false;
  final _waits = <Timer, Completer<void>>{};
  void cancel() {
    canceled = true;
    for (final entry in _waits.entries) {
      entry.key.cancel();
      if (!entry.value.isCompleted) entry.value.complete();
    }
    _waits.clear();
  }

  Future<void> wait(Duration duration) {
    if (canceled) return Future.value();
    final completed = Completer<void>();
    late Timer timer;
    timer = Timer(duration, () {
      _waits.remove(timer);
      completed.complete();
    });
    _waits[timer] = completed;
    return completed.future;
  }
}

abstract interface class AiTemplateJobProvider {
  Future<AiTemplateJob?> latestTemplateJob();
  Future<AiTemplateJob> templateJobStatus(String requestId);
  Future<AiTemplateJob> cancelTemplateJob(String requestId);
  Future<AlbumRecommendationDraft> createTemplateJob(
    AiTemplateBrief brief, {
    required String requestId,
    AiTemplatePollingToken? token,
    void Function(AiTemplateJob)? onProgress,
  });
  Future<AlbumRecommendationDraft> resumeTemplateJob(
    AiTemplateJob job, {
    AiTemplatePollingToken? token,
    void Function(AiTemplateJob)? onProgress,
  });
}
