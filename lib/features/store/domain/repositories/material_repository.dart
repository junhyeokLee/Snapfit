import '../entities/catalog_material.dart';

abstract class MaterialRepository {
  Future<List<CatalogMaterial>> getMaterials();
  Future<void> likeMaterial(String productKey);
}
