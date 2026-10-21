/// Acceptance is deliberately distinct from account or file deletion.
class AccountDeletionRequest {
  const AccountDeletionRequest({
    required this.reference,
    required this.alreadyRequested,
  });
  final String reference;
  final bool alreadyRequested;

  factory AccountDeletionRequest.fromJson(Map<String, dynamic> json) {
    final reference = json['reference'];
    if (json['requestAccepted'] != true ||
        json['accountDeleted'] != false ||
        json['alreadyRequested'] is! bool ||
        reference is! String ||
        !RegExp(r'^DEL-[1-9][0-9]{0,18}$').hasMatch(reference)) {
      throw const FormatException('account_deletion_request_invalid');
    }
    return AccountDeletionRequest(
      reference: reference,
      alreadyRequested: json['alreadyRequested'] as bool,
    );
  }
}
