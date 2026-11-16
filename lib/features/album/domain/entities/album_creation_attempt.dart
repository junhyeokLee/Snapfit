import '../../data/dto/request/create_album_request.dart';

/// A durable immutable create command. Edits after a lost response belong to a
/// later document save; replay must always send this exact original seed.
class AlbumCreationAttempt {
  const AlbumCreationAttempt({
    required this.ownerId,
    required this.draftId,
    required this.requestId,
    required this.seed,
  });

  final String ownerId, draftId, requestId;
  final CreateAlbumRequest seed;

  Map<String, dynamic> toJson() => {
    'ownerId': ownerId,
    'draftId': draftId,
    'requestId': requestId,
    'seed': seed.toJson(),
  };

  factory AlbumCreationAttempt.fromJson(Map<String, dynamic> json) {
    final owner = json['ownerId'];
    final draft = json['draftId'];
    final request = json['requestId'];
    if (owner is! String ||
        owner.isEmpty ||
        draft is! String ||
        draft.isEmpty ||
        request is! String ||
        !RegExp(
          r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
        ).hasMatch(request) ||
        json['seed'] is! Map) {
      throw const FormatException('Invalid album creation attempt');
    }
    return AlbumCreationAttempt(
      ownerId: owner,
      draftId: draft,
      requestId: request,
      seed: CreateAlbumRequest.fromJson(
        Map<String, dynamic>.from(json['seed'] as Map),
      ),
    );
  }
}
