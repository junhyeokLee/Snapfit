// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'invite_accept_response.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_InviteAcceptResponse _$InviteAcceptResponseFromJson(
  Map<String, dynamic> json,
) => _InviteAcceptResponse(
  albumId: (json['albumId'] as num).toInt(),
  role: json['role'] as String,
  success: json['success'] as bool,
);

Map<String, dynamic> _$InviteAcceptResponseToJson(
  _InviteAcceptResponse instance,
) => <String, dynamic>{
  'albumId': instance.albumId,
  'role': instance.role,
  'success': instance.success,
};
