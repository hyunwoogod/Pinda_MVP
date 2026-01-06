class LocationUtils {
  // 서울의 대략적인 사각형 범위
  // 북단: 37.7015 (도봉구)
  // 남단: 37.4350 (서초/관악)
  // 서단: 126.7650 (강서)
  // 동단: 127.1850 (강동)
  static const double seoulMinLat = 37.40;
  static const double seoulMaxLat = 37.72;
  static const double seoulMinLng = 126.75;
  static const double seoulMaxLng = 127.20;

  static bool isInSeoul(double lat, double lng) {
    return lat >= seoulMinLat &&
        lat <= seoulMaxLat &&
        lng >= seoulMinLng &&
        lng <= seoulMaxLng;
  }
}
