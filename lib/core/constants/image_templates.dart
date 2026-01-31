/// 이미지 슬롯 템플릿: 정사각형, 4:3 등 비율 고정 + 사진이 슬롯에 꽉 차게(cover) 적용
class ImageTemplate {
  final String key;
  final String label;
  /// width / height. null이면 원본 사진 비율 유지(free)
  final double? aspect;

  const ImageTemplate({
    required this.key,
    required this.label,
    this.aspect,
  });
}

const List<ImageTemplate> imageTemplates = [
  ImageTemplate(key: 'free', label: '자유', aspect: null),
  ImageTemplate(key: '1:1', label: '정사각형', aspect: 1.0),
  ImageTemplate(key: '4:3', label: '4:3', aspect: 4 / 3),
  ImageTemplate(key: '3:4', label: '3:4', aspect: 3 / 4),
  ImageTemplate(key: '16:9', label: '16:9', aspect: 16 / 9),
  ImageTemplate(key: '9:16', label: '9:16', aspect: 9 / 16),
  ImageTemplate(key: '3:2', label: '3:2', aspect: 3 / 2),
  ImageTemplate(key: '2:3', label: '2:3', aspect: 2 / 3),
];

double? aspectForTemplateKey(String? key) {
  if (key == null || key == 'free') return null;
  for (final t in imageTemplates) {
    if (t.key == key) return t.aspect;
  }
  return null;
}
