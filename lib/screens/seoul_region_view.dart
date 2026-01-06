import 'package:flutter/material.dart';
import '../widgets/naver_map_web.dart';
import '../data/seoul_data.dart';
import 'map_view.dart'; // Reusing MapView as Detail View for now

class SeoulRegionView extends StatefulWidget {
  static final GlobalKey<SeoulRegionViewState> globalKey = GlobalKey();
  const SeoulRegionView({super.key});

  @override
  State<SeoulRegionView> createState() => SeoulRegionViewState();
}

class SeoulRegionViewState extends State<SeoulRegionView> {
  NaverMapWebController? _mapController;

  // 서울 중심
  final double _seoulLat = 37.5665;
  final double _seoulLng = 126.9780;
  final double _initialZoom = 11;

  String? _selectedGuId;

  void _onPolygonTapped(SeoulDistrict district) {
    setState(() {
      if (_selectedGuId == district.id) {
        // 이미 선택된 구를 다시 누르면 -> 상세 지도로 이동
        _navigateToDetail(district);
      } else {
        // 새로운 구 선택 -> 하이라이트 및 카메라 이동
        _selectedGuId = district.id;
        _mapController?.moveCamera(district.centerLat, district.centerLng,
            zoom: 13); // 약간 줌인
      }
    });
  }

  void _navigateToDetail(SeoulDistrict district) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MapView(
          initialLat: district.centerLat,
          initialLng: district.centerLng,
          initialZoom: 15,
          districtName: district.name,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // 폴리곤 리스트 생성
    final polygons = seoulDistricts.map((district) {
      final isSelected = _selectedGuId == district.id;
      return NaverMapPolygon(
        id: district.id,
        coordinates: district.boundary,
        // 선택됨: 파랑 테두리 굵게, 내부 투명 (또는 아주 연한 파랑)
        // 안선택됨: 회색 테두리 얇게, 내부 아주 연한 회색/파랑
        color: isSelected ? Colors.blue.withOpacity(0.1) : Colors.transparent,
        strokeColor: isSelected ? Colors.blue[700]! : Colors.grey[400]!,
        strokeWidth: isSelected ? 4 : 2,
        zIndex: isSelected ? 2 : 1, // 선택된 구 > 일반 구
        onTap: () => _onPolygonTapped(district),
      );
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text("서울 지도 (구 선택)"), // 임시 타이틀, MainScreen에서 덮어씌워질 수 있음
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black,
      ),
      body: Stack(
        children: [
          NaverMapWeb(
            latitude: _seoulLat,
            longitude: _seoulLng,
            zoom: _initialZoom,
            polygons: polygons,
            onMapReady: (controller) {
              _mapController = controller;
            },
          ),
          // 안내 메시지
          Positioned(
            top: 20,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.9),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 4,
                    )
                  ],
                ),
                child: Text(
                  _selectedGuId == null
                      ? "궁금한 구를 선택해주세요!"
                      : "한 번 더 누르면 ${seoulDistricts.firstWhere((d) => d.id == _selectedGuId).name}로 이동합니다.",
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
