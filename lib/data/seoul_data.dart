import '../widgets/naver_map_web.dart';

class SeoulDistrict {
  final String id;
  final String name;
  final double centerLat;
  final double centerLng;
  final List<NaverLatLng> boundary;

  const SeoulDistrict({
    required this.id,
    required this.name,
    required this.centerLat,
    required this.centerLng,
    required this.boundary,
  });
}

// 간단한 사각형 폴리곤 생성 헬퍼
List<NaverLatLng> _createBox(double centerLat, double centerLng, double size) {
  return [
    NaverLatLng(centerLat + size, centerLng - size), // Top-Left
    NaverLatLng(centerLat + size, centerLng + size), // Top-Right
    NaverLatLng(centerLat - size, centerLng + size), // Bottom-Right
    NaverLatLng(centerLat - size, centerLng - size), // Bottom-Left
  ];
}

// 25개 구 데이터 (중심 좌표 기준 대략적인 박스)
// 실제 GeoJSON 데이터가 없어 중심점 기준으로 시각화함
final List<SeoulDistrict> seoulDistricts = [
  SeoulDistrict(
      id: 'gangnam',
      name: '강남구',
      centerLat: 37.5172,
      centerLng: 127.0473,
      boundary: _createBox(37.5172, 127.0473, 0.015)),
  SeoulDistrict(
      id: 'gangdong',
      name: '강동구',
      centerLat: 37.5301,
      centerLng: 127.1238,
      boundary: _createBox(37.5301, 127.1238, 0.015)),
  SeoulDistrict(
      id: 'gangbuk',
      name: '강북구',
      centerLat: 37.6396,
      centerLng: 127.0257,
      boundary: _createBox(37.6396, 127.0257, 0.015)),
  SeoulDistrict(
      id: 'gangseo',
      name: '강서구',
      centerLat: 37.5509,
      centerLng: 126.8497,
      boundary: _createBox(37.5509, 126.8497, 0.015)),
  SeoulDistrict(
      id: 'gwanak',
      name: '관악구',
      centerLat: 37.4784,
      centerLng: 126.9516,
      boundary: _createBox(37.4784, 126.9516, 0.015)),
  SeoulDistrict(
      id: 'gwangjin',
      name: '광진구',
      centerLat: 37.5385,
      centerLng: 127.0824,
      boundary: _createBox(37.5385, 127.0824, 0.012)),
  SeoulDistrict(
      id: 'guro',
      name: '구로구',
      centerLat: 37.4954,
      centerLng: 126.8874,
      boundary: _createBox(37.4954, 126.8874, 0.012)),
  SeoulDistrict(
      id: 'geumcheon',
      name: '금천구',
      centerLat: 37.4565,
      centerLng: 126.8954,
      boundary: _createBox(37.4565, 126.8954, 0.012)),
  SeoulDistrict(
      id: 'nowon',
      name: '노원구',
      centerLat: 37.6542,
      centerLng: 127.0568,
      boundary: _createBox(37.6542, 127.0568, 0.015)),
  SeoulDistrict(
      id: 'dobong',
      name: '도봉구',
      centerLat: 37.6688,
      centerLng: 127.0471,
      boundary: _createBox(37.6688, 127.0471, 0.012)),
  SeoulDistrict(
      id: 'dongdaemun',
      name: '동대문구',
      centerLat: 37.5744,
      centerLng: 127.0400,
      boundary: _createBox(37.5744, 127.0400, 0.012)),
  SeoulDistrict(
      id: 'dongjak',
      name: '동작구',
      centerLat: 37.5124,
      centerLng: 126.9393,
      boundary: _createBox(37.5124, 126.9393, 0.012)),
  SeoulDistrict(
      id: 'mapo',
      name: '마포구',
      centerLat: 37.5661,
      centerLng: 126.9016,
      boundary: _createBox(37.5661, 126.9016, 0.015)),
  SeoulDistrict(
      id: 'seodaemun',
      name: '서대문구',
      centerLat: 37.5791,
      centerLng: 126.9368,
      boundary: _createBox(37.5791, 126.9368, 0.012)),
  SeoulDistrict(
      id: 'seocho',
      name: '서초구',
      centerLat: 37.4837,
      centerLng: 127.0324,
      boundary: _createBox(37.4837, 127.0324, 0.018)),
  SeoulDistrict(
      id: 'seongdong',
      name: '성동구',
      centerLat: 37.5633,
      centerLng: 127.0371,
      boundary: _createBox(37.5633, 127.0371, 0.012)),
  SeoulDistrict(
      id: 'seongbuk',
      name: '성북구',
      centerLat: 37.6069,
      centerLng: 127.0232,
      boundary: _createBox(37.6069, 127.0232, 0.015)),
  SeoulDistrict(
      id: 'songpa',
      name: '송파구',
      centerLat: 37.5145,
      centerLng: 127.1066,
      boundary: _createBox(37.5145, 127.1066, 0.018)),
  SeoulDistrict(
      id: 'yangcheon',
      name: '양천구',
      centerLat: 37.5169,
      centerLng: 126.8660,
      boundary: _createBox(37.5169, 126.8660, 0.012)),
  SeoulDistrict(
      id: 'yeongdeungpo',
      name: '영등포구',
      centerLat: 37.5264,
      centerLng: 126.8962,
      boundary: _createBox(37.5264, 126.8962, 0.012)),
  SeoulDistrict(
      id: 'yongsan',
      name: '용산구',
      centerLat: 37.5326,
      centerLng: 126.9904,
      boundary: _createBox(37.5326, 126.9904, 0.012)),
  SeoulDistrict(
      id: 'eunpyeong',
      name: '은평구',
      centerLat: 37.6027,
      centerLng: 126.9291,
      boundary: _createBox(37.6027, 126.9291, 0.015)),
  SeoulDistrict(
      id: 'jongno',
      name: '종로구',
      centerLat: 37.5730,
      centerLng: 126.9794,
      boundary: _createBox(37.5730, 126.9794, 0.012)),
  SeoulDistrict(
      id: 'jung',
      name: '중구',
      centerLat: 37.5641,
      centerLng: 126.9979,
      boundary: _createBox(37.5641, 126.9979, 0.01)),
  SeoulDistrict(
      id: 'jungnang',
      name: '중랑구',
      centerLat: 37.6063,
      centerLng: 127.0926,
      boundary: _createBox(37.6063, 127.0926, 0.012)),
];
