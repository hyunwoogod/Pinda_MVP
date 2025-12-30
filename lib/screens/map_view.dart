import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:async';
import '../widgets/naver_map_web.dart';
import 'camera_screen.dart';

// --- 1. 지도 뷰 (Map View) ---
class MapView extends StatefulWidget {
  const MapView({super.key});

  @override
  State<MapView> createState() => _MapViewState();
}

class _MapViewState extends State<MapView> {
  NaverMapWebController? _mapController;

  // 초기 카메라 위치 (서울 시청)
  final double _initialLat = 37.5665;
  final double _initialLng = 126.9780;

  // 미션 마커들
  List<NaverMapMarker> get _missionMarkers => [
        NaverMapMarker(
          id: "hufs_main",
          latitude: 37.5973,
          longitude: 127.0583,
          title: "외대 정문",
          onTap: () => _showMissionDialog("외대 정문", "순대차 왔나요?"),
        ),
        NaverMapMarker(
          id: "gs25_imun",
          latitude: 37.5966,
          longitude: 127.0601,
          title: "GS25 이문점",
          onTap: () => _showMissionDialog("GS25 이문점", "두바이 초콜릿 재고 있나요?"),
        ),
        NaverMapMarker(
          id: "library_main",
          latitude: 37.5955,
          longitude: 127.0528,
          title: "중앙도서관",
          onTap: () => _showMissionDialog("중앙도서관", "3열람실 자리 있나요?"),
        ),
      ];

  @override
  void initState() {
    super.initState();
    _checkPermission();
  }

  Future<void> _checkPermission() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
  }

  void _showMissionDialog(String title, String question) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Q. $question",
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            const Text("💰 보상: 에어팟 응모권 1장"),
            const SizedBox(height: 5),
            const Text("📸 미션: 현재 상황 사진 찍기"),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("닫기"),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const CameraScreen()),
              );
            },
            child: const Text("답변하기"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          SizedBox.expand(
            child: NaverMapWeb(
              latitude: _initialLat,
              longitude: _initialLng,
              zoom: 14,
              markers: _missionMarkers,
              onMapReady: (controller) {
                _mapController = controller;
              },
            ),
          ),

          // 상단 검색 버튼
          Positioned(
            top: 50,
            left: 20,
            right: 20,
            child: SizedBox(
              height: 50,
              child: ElevatedButton.icon(
                onPressed: _showAddressSearchDialog,
                icon: const Icon(Icons.search),
                label: const Text("주소 검색"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black,
                  elevation: 2,
                  alignment: Alignment.centerLeft,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showAddressSearchDialog() {
    final TextEditingController searchController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("주소 직접 입력"),
        content: TextField(
          controller: searchController,
          decoration: const InputDecoration(
            hintText: "예: 수내동, 판교역",
            border: OutlineInputBorder(),
          ),
          onSubmitted: (value) {
            Navigator.pop(context);
            _searchAddress(value);
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("취소"),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _searchAddress(searchController.text);
            },
            child: const Text("이동"),
          ),
        ],
      ),
    );
  }

  Future<void> _searchAddress(String query) async {
    if (query.isEmpty) return;
    try {
      // 네이버 지오코딩 API 사용
      final results = await NaverGeocodingService.geocode(query);

      if (results.isNotEmpty) {
        final result = results.first;
        // 카메라 이동
        _mapController?.moveCamera(result.latitude, result.longitude, zoom: 16);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("검색 결과가 없습니다.")),
          );
        }
      }
    } catch (e) {
      debugPrint('Address search error: $e');
    }
  }
}
