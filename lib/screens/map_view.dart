import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'camera_screen.dart';

// --- 1. 지도 뷰 (Map View) ---
class MapView extends StatefulWidget {
  const MapView({super.key});

  @override
  State<MapView> createState() => _MapViewState();
}

class _MapViewState extends State<MapView> {
  final MapController _mapController = MapController();

  // 초기 카메라 위치 (서울 시청)
  static const LatLng _kSeoul = LatLng(37.5665, 126.9780);

  // 마커 목록
  List<Marker> _markers = [];
  LatLng? _currentPosition;
  StreamSubscription<Position>? _positionStreamSubscription;
  bool _isTracking = false;
  // bool _isManualLocation = false; // [Lint Fix] Unused variable removed

  @override
  void initState() {
    super.initState();
    _initMarkers();
    _checkPermissionAndStartTracking();
  }

  @override
  void dispose() {
    _positionStreamSubscription?.cancel();
    // _mapController.dispose(); // Flutter Map 6.x+ doesn't require disposal
    super.dispose();
  }

  // 초기 마커 데이터 설정
  void _initMarkers() {
    setState(() {
      _markers = [
        _buildMarker(
          const LatLng(37.5973, 127.0583),
          "외대 정문",
          "순대차 왔나요?",
          Colors.red,
        ),
        _buildMarker(
          const LatLng(37.5966, 127.0601),
          "GS25 이문점",
          "두바이 초콜릿 재고 있나요?",
          Colors.orange,
        ),
        _buildMarker(
          const LatLng(37.5955, 127.0528),
          "중앙도서관",
          "3열람실 자리 있나요?",
          Colors.blue,
        ),
      ];
    });
  }

  Marker _buildMarker(
    LatLng point,
    String title,
    String question,
    Color color,
  ) {
    return Marker(
      point: point,
      width: 80,
      height: 80,
      child: GestureDetector(
        onTap: () => _showMissionDialog(title, question),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  const BoxShadow(blurRadius: 3, color: Colors.black26),
                ],
              ),
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Icon(Icons.location_on, size: 40, color: color),
          ],
        ),
      ),
    );
  }

  Future<void> _checkPermissionAndStartTracking() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('위치 서비스가 비활성화되어 있습니다.')));
      }
      return;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('위치 권한이 거부되었습니다.')));
        }
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('위치 권한이 영구적으로 거부되었습니다.')));
      }
      return;
    }

    setState(() {
      _isTracking = true;
    });

    try {
      Position? lastKnownPosition = await Geolocator.getLastKnownPosition();
      if (lastKnownPosition != null) {
        final now = DateTime.now();
        if (now.difference(lastKnownPosition.timestamp).inMinutes < 5) {
          _updatePosition(lastKnownPosition, source: "최근 위치 (캐시)");
        }
      }
    } catch (e) {
      debugPrint("Error getting last known position: $e");
    }

    Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
      timeLimit: const Duration(seconds: 10),
    ).then((position) {
      _updatePosition(position, source: "GPS/WiFi 위치");
    }).catchError((e) {
      debugPrint("Core location fetch failed ($e), trying IP location...");
      _fetchLocationByIp();
    });

    _positionStreamSubscription?.cancel();
    _positionStreamSubscription = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5,
      ),
    ).listen(
      (Position position) {
        _updatePosition(position);
      },
      onError: (e) {
        debugPrint("Location stream error: $e");
      },
    );
  }

  Future<void> _fetchLocationByIp() async {
    try {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('GPS 신호가 약해 IP로 위치를 찾습니다...')),
        );
      }
      final response = await http.get(Uri.parse('http://ip-api.com/json'));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'success') {
          final double lat = data['lat'];
          final double lon = data['lon'];
          final String city = data['city'] ?? "IP Location";

          _updatePosition(
            Position(
              latitude: lat,
              longitude: lon,
              timestamp: DateTime.now(),
              accuracy: 0,
              altitude: 0,
              heading: 0,
              speed: 0,
              speedAccuracy: 0,
              altitudeAccuracy: 0,
              headingAccuracy: 0,
            ),
            source: "IP 위치: $city",
          );
        }
      }
    } catch (e) {
      debugPrint('IP location failed: $e');
    }
  }

  void _updatePosition(Position position, {String? source}) {
    if (!mounted) return;
    setState(() {
      _currentPosition = LatLng(position.latitude, position.longitude);
    });
    if (_isTracking && _currentPosition != null) {
      _mapController.move(_currentPosition!, 16.0);
    }

    if (source != null && mounted) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("위치 갱신: $source"),
          duration: const Duration(seconds: 2),
        ),
      );
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
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _kSeoul,
              initialZoom: 14.0,
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
              ),
              onPositionChanged: (position, hasGesture) {
                if (hasGesture && _isTracking) {
                  setState(() {
                    _isTracking = false;
                    // _isManualLocation = false;
                  });
                }
              },
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.app',
              ),
              MarkerLayer(markers: _markers),
              if (_currentPosition != null)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: _currentPosition!,
                      width: 20,
                      height: 20,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.blue.withOpacity(0.7),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                          boxShadow: [
                            const BoxShadow(
                              blurRadius: 5,
                              color: Colors.blueAccent,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
            ],
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

          // 하단 내 위치 버튼
          Positioned(
            bottom: 30,
            right: 20,
            child: FloatingActionButton(
              heroTag: 'location',
              onPressed: () {
                setState(() {
                  _isTracking = true;
                  // _isManualLocation = true;
                });
                _positionStreamSubscription?.cancel();
                _updatePosition(
                  Position(
                    latitude: 37.597081,
                    longitude: 127.058741,
                    timestamp: DateTime.now(),
                    accuracy: 0,
                    altitude: 0,
                    heading: 0,
                    speed: 0,
                    speedAccuracy: 0,
                    altitudeAccuracy: 0,
                    headingAccuracy: 0,
                  ),
                  source: "기본 위치 (한국외대 정문)",
                );
              },
              backgroundColor: Colors.white,
              foregroundColor: Colors.black,
              child: Icon(
                _isTracking ? Icons.gps_fixed : Icons.gps_not_fixed,
                color: _isTracking ? Colors.blue : null,
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
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/search?q=$query&format=json&accept-language=ko',
      );
      final response = await http.get(
        url,
        headers: {
          'User-Agent': 'NowHereApp/1.0',
        },
      );

      if (response.statusCode == 200) {
        final List data = json.decode(response.body);
        if (data.isNotEmpty) {
          final lat = double.parse(data[0]['lat']);
          final lon = double.parse(data[0]['lon']);

          setState(() {
            _isTracking = true;
            // _isManualLocation = true;
          });

          _positionStreamSubscription?.cancel();

          _updatePosition(
            Position(
              latitude: lat,
              longitude: lon,
              timestamp: DateTime.now(),
              accuracy: 0,
              altitude: 0,
              heading: 0,
              speed: 0,
              speedAccuracy: 0,
              altitudeAccuracy: 0,
              headingAccuracy: 0,
            ),
            source: "검색 위치 이동",
          );
        }
      }
    } catch (e) {
      debugPrint('Address search error: $e');
    }
  }
}
