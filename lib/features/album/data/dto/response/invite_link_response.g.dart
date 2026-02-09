// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'invite_link_response.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_InviteLinkResponse _$InviteLinkResponseFromJson(Map<String, dynamic> json) =>
    _InviteLinkResponse(
      albumId: (json['albumId'] as num).toInt(),
      token: json['token'] as String,
      link: json['link'] as String,
    );

Map<String, dynamic> _$InviteLinkResponseToJson(_InviteLinkResponse instance) =>
    <String, dynamic>{
      'albumId': instance.albumId,
      'token': instance.token,
      'link': instance.link,
    };
