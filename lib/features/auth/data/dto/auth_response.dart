import 'package:freezed_annotation/freezed_annotation.dart';

part 'auth_response.freezed.dart';
part 'auth_response.g.dart';

@Freezed(toStringOverride: false)
sealed class AuthResponse with _$AuthResponse {
  const AuthResponse._();

  const factory AuthResponse({
    required String accessToken,
    required String refreshToken,
    required int expiresIn,
    required UserInfo user,
  }) = _AuthResponse;

  factory AuthResponse.fromJson(Map<String, dynamic> json) =>
      _$AuthResponseFromJson(json);

  @override
  String toString() {
    return 'AuthResponse(accessToken: [REDACTED], refreshToken: [REDACTED], expiresIn: $expiresIn, user: $user)';
  }
}

@freezed
sealed class UserInfo with _$UserInfo {
  const factory UserInfo({
    required String id,
    String? email,
    required String name,
    String? profileImageUrl,
    required String provider,
  }) = _UserInfo;

  factory UserInfo.fromJson(Map<String, dynamic> json) =>
      _$UserInfoFromJson(json);
}
