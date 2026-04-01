import 'package:dio/dio.dart';
import 'package:retrofit/retrofit.dart';
import '../../domain/entities/premium_template.dart';
import '../../../album/domain/entities/album.dart';

part 'template_api.g.dart';

@RestApi()
abstract class TemplateApi {
  factory TemplateApi(Dio dio) = _TemplateApi;

  @GET('/api/templates')
  Future<List<PremiumTemplate>> getTemplates(@Query('userId') String? userId);

  @GET('/api/templates/summary')
  Future<dynamic> getTemplateSummaries(
    @Query('userId') String? userId,
    @Query('page') int page,
    @Query('size') int size,
  );

  @GET('/api/templates/{id}')
  Future<PremiumTemplate> getTemplate(
    @Path('id') int id,
    @Query('userId') String? userId,
  );

  @POST('/api/templates/{id}/like')
  Future<void> likeTemplate(@Path('id') int id, @Query('userId') String userId);

  @POST('/api/templates/{id}/use')
  Future<Album> createAlbumFromTemplate(
    @Path('id') int id,
    @Query('userId') String userId,
    @Body() Map<String, String>? replacements,
  );
}
