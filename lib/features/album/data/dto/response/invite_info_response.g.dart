// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'invite_info_response.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_InviteInfoResponse _$InviteInfoResponseFromJson(Map<String, dynamic> json) =>
    _InviteInfoResponse(
      albumId: (json['albumId'] as num).toInt(),
      albumTitle: json['albumTitle'] as String,
      inviterName: json['inviterName'] as String,
      role: json['role'] as String,
    );

Map<String, dynamic> _$InviteInfoResponseToJson(_InviteInfoResponse instance) =>
    <String, dynamic>{
      'albumId': instance.albumId,
      'albumTitle': instance.albumTitle,
      'inviterName': instance.inviterName,
      'role': instance.role,
    };
