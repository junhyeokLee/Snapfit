// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'album_member_response.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_AlbumMemberResponse _$AlbumMemberResponseFromJson(Map<String, dynamic> json) =>
    _AlbumMemberResponse(
      id: (json['id'] as num).toInt(),
      userId: (json['userId'] as num).toInt(),
      userName: json['userName'] as String?,
      userEmail: json['userEmail'] as String?,
      profileImageUrl: json['profileImageUrl'] as String?,
      role: json['role'] as String,
      status: json['status'] as String,
    );

Map<String, dynamic> _$AlbumMemberResponseToJson(
  _AlbumMemberResponse instance,
) => <String, dynamic>{
  'id': instance.id,
  'userId': instance.userId,
  'userName': instance.userName,
  'userEmail': instance.userEmail,
  'profileImageUrl': instance.profileImageUrl,
  'role': instance.role,
  'status': instance.status,
};
