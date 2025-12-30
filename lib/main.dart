import 'package:flutter/material.dart';
import 'dart:async'; // AI 처리 시간 시뮬레이션용
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

// --- 데이터 모델 & 상태 관리 ---
class UserModel {
  final String nickname;
  final int level;
  final int tickets;

  UserModel({
    required this.nickname,
    required this.level,
    required this.tickets,
  });
}

// 전역 로그인 상태 (ValueNotifier): null이면 비로그인
final ValueNotifier<UserModel?> currentUser = ValueNotifier(null);

final GlobalKey<MainScreenState> globalMainKey = GlobalKey<MainScreenState>();

void main() {
  runApp(const PindaApp());
}

class PindaApp extends StatelessWidget {
  const PindaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Pinda',
      theme: ThemeData(primarySwatch: Colors.blue, useMaterial3: true),
      home: MainScreen(key: globalMainKey),
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => MainScreenState();
}

class MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;

  // 화면 4개: 지도, 질문 등록, 응모, 마이페이지
  static final List<Widget> _widgetOptions = <Widget>[
    const MapView(), // 1. 지도
    const QuestionView(), // 2. 질문 등록 (New)
    const ApplyView(), // 3. 응모 (New)
    const MyPageView(), // 4. 마이페이지
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  // 외부에서 탭 전환 호출용
  void switchToTab(int index) {
    _onItemTapped(index);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // AppBar 제거로 Full Screen 효과
      body: _widgetOptions.elementAt(_selectedIndex),
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(icon: Icon(Icons.map), label: '지도'),
          BottomNavigationBarItem(icon: Icon(Icons.edit), label: '질문 등록'),
          BottomNavigationBarItem(icon: Icon(Icons.card_giftcard), label: '응모'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: '내 정보'),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.blue,
        unselectedItemColor: Colors.grey, // 비활성 아이콘 색상 추가
        showUnselectedLabels: true, // 라벨 항상 표시
        type: BottomNavigationBarType.fixed, // 4개 이상일 때 레이아웃 유지
        onTap: _onItemTapped,
      ),
    );
  }
}

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
  bool _isManualLocation = false; // 수동 위치 고정 여부

  @override
  void initState() {
    super.initState();
    _initMarkers();
    _checkPermissionAndStartTracking();
  }

  @override
  void dispose() {
    _positionStreamSubscription?.cancel();
    _mapController.dispose();
    super.dispose();
  }

  // 초기 마커 데이터 설정
  void _initMarkers() {
    setState(() {
      _markers = [
        _buildMarker(
          const LatLng(37.5973, 127.0583), // 외대 정문 얼추 근처
          "외대 정문",
          "순대차 왔나요?",
          Colors.red,
        ),
        _buildMarker(
          const LatLng(37.5966, 127.0601), // 이문동 근처
          "GS25 이문점",
          "두바이 초콜릿 재고 있나요?",
          Colors.orange,
        ),
        _buildMarker(
          const LatLng(37.5955, 127.0528), // 근처 도서관 가정
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

    // 권한 확보됨, 추적 시작
    setState(() {
      _isTracking = true;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('위치를 찾고 있습니다...'),
        duration: Duration(seconds: 1),
      ),
    );

    // 1. 마지막으로 알려진 위치 먼저 확인 (가장 빠름)
    try {
      Position? lastKnownPosition = await Geolocator.getLastKnownPosition();
      if (lastKnownPosition != null) {
        // 캐시된 위치가 5분 이내인 경우에만 사용
        final now = DateTime.now();
        if (now.difference(lastKnownPosition.timestamp).inMinutes < 5) {
          _updatePosition(lastKnownPosition, source: "최근 위치 (캐시)");
        }
      }
    } catch (e) {
      debugPrint("Error getting last known position: $e");
    }

    // 2. 현재 위치 시도 (타임아웃 늘림 & 실패 시 무시하고 스트림 의존)
    // await를 사용하지 않고 비동기로 실행하여 UI 블로킹 방지 및 타임아웃 에러 시 조용히 처리
    Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
          timeLimit: const Duration(seconds: 10),
        )
        .then((position) {
          _updatePosition(position, source: "GPS/WiFi 위치");
        })
        .catchError((e) {
          debugPrint("Core location fetch failed ($e), trying IP location...");
          _fetchLocationByIp(); // GPS 실패 시 IP 위치 시도
        });

    // 3. 위치 스트림 구독 (실시간 이동 반영)
    _positionStreamSubscription?.cancel();
    _positionStreamSubscription =
        Geolocator.getPositionStream(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            distanceFilter: 5, // 5미터 이동 시 업데이트
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

  // IP 기반 위치 추적 (PC/LAN 환경 대응)
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
              // 촬영 화면으로 이동 (탭 아님)
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
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // 1. 지도 레이어 (가장 아래)
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
                    _isManualLocation = false;
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

          // 2. 상단 검색 버튼
          Positioned(
            top: 50,
            left: 20,
            right: 20,
            child: SizedBox(
              height: 50,
              child: ElevatedButton.icon(
                onPressed: _showAddressSearchDialog,
                icon: const Icon(Icons.search),
                label: const Text("주소 검색"), // 텍스트 간소화
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

          // 3. 하단 내 위치 버튼 (아이콘만)
          Positioned(
            bottom: 30,
            right: 20,
            child: FloatingActionButton(
              heroTag: 'location',
              onPressed: () {
                // 한국외대 정문으로 고정
                setState(() {
                  _isTracking = true;
                  _isManualLocation = true; // 고정 모드
                });

                // 스트림 취소
                _positionStreamSubscription?.cancel();

                // 한국외대 정문 좌표 (37.597081, 127.058741)
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

  // 주소 검색 다이얼로그 (수동 입력)
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

  // 주소 -> 좌표 변환 (Nominatim API - OSM)
  Future<void> _searchAddress(String query) async {
    if (query.isEmpty) return;
    try {
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/search?q=$query&format=json&accept-language=ko',
      );
      final response = await http.get(
        url,
        headers: {
          'User-Agent': 'NowHereApp/1.0', // OSM 정책 준수
        },
      );

      if (response.statusCode == 200) {
        final List data = json.decode(response.body);
        if (data.isNotEmpty) {
          final lat = double.parse(data[0]['lat']);
          final lon = double.parse(data[0]['lon']);
          final displayName = data[0]['display_name'];

          // 검색 결과로 이동 시 트래킹 모드 활성화 & 수동 위치 고정 (자동 업데이트 중단)
          setState(() {
            _isTracking = true;
            _isManualLocation = true; // [New] 수동 고정 모드
          });

          // 자동 업데이트 스트림 취소 (위치 튀는 것 방지)
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
            source: "검색 고정: $query",
          );

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("위치가 고정되었습니다. (자동 업데이트 중지)")),
          );

          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text("검색 완료: $displayName")));
        } else {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text("검색 결과가 없습니다.")));
        }
      }
    } catch (e) {
      debugPrint("Search failed: $e");
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("검색 실패: $e")));
    }
  }
}

// --- 2. 질문 등록 뷰 (Question View: Form) ---
// --- 2. 질문 등록 뷰 (Question View: Form) ---
class QuestionView extends StatefulWidget {
  const QuestionView({super.key});

  @override
  State<QuestionView> createState() => _QuestionViewState();
}

class _QuestionViewState extends State<QuestionView> {
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  final _locationController = TextEditingController();

  // 지도 관련
  final MapController _mapController = MapController();
  // 초기 위치: 한국외대 정문 (기본값)
  LatLng _selectedLocation = const LatLng(37.5973, 127.0583);
  List<Marker> _markers = [];
  bool _isMapInteractive = false;

  @override
  void initState() {
    super.initState();
    // 초기 마커 설정
    _updateMarker(_selectedLocation);
    // 초기 위치의 주소 가져오기
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _reverseGeocode(_selectedLocation);
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    _locationController.dispose();
    _mapController.dispose();
    super.dispose();
  }

  // 마커 업데이트
  void _updateMarker(LatLng point) {
    setState(() {
      _selectedLocation = point;
      _markers = [
        Marker(
          point: point,
          width: 50,
          height: 50,
          child: Transform.translate(
            offset: Offset(0, -20), // 핀 끝이 지점에 닿도록 조정
            child: Icon(Icons.location_on, color: Colors.red, size: 40),
          ),
        ),
      ];
    });
  }

  // 지도 탭 핸들러 (핀 이동)
  void _onMapTap(TapPosition tapPosition, LatLng point) {
    _updateMarker(point);
    _reverseGeocode(point);
  }

  // 좌표 -> 주소 변환 (Reverse Geocoding)
  Future<void> _reverseGeocode(LatLng point) async {
    try {
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse?format=json&lat=${point.latitude}&lon=${point.longitude}&zoom=18&addressdetails=1&accept-language=ko',
      );
      final response = await http.get(
        url,
        headers: {'User-Agent': 'NowHereApp/1.0'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data != null && data['display_name'] != null) {
          setState(() {
            _locationController.text = data['display_name'];
          });
        }
      }
    } catch (e) {
      debugPrint("Reverse geocoding failed: $e");
    }
  }

  // 주소 검색 로직
  Future<void> _searchAddress(String query) async {
    if (query.isEmpty) return;
    try {
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/search?q=$query&format=json&accept-language=ko',
      );
      final response = await http.get(
        url,
        headers: {'User-Agent': 'NowHereApp/1.0'},
      );

      if (response.statusCode == 200) {
        final List data = json.decode(response.body);
        if (data.isNotEmpty) {
          final lat = double.parse(data[0]['lat']);
          final lon = double.parse(data[0]['lon']);
          final displayName = data[0]['display_name'];

          final newPoint = LatLng(lat, lon);
          _updateMarker(newPoint);

          setState(() {
            _locationController.text = displayName;
          });

          // 지도 이동
          _mapController.move(newPoint, 16.0);
        } else {
          if (mounted) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(const SnackBar(content: Text("검색 결과가 없습니다.")));
          }
        }
      }
    } catch (e) {
      debugPrint("Question search failed: $e");
    }
  }

  // 주소 검색 다이얼로그
  void _showAddressSearchDialog() {
    final TextEditingController searchController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("장소 검색"),
        content: TextField(
          controller: searchController,
          decoration: const InputDecoration(
            hintText: "예: 한국외대, 외대역",
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
            child: const Text("검색"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<UserModel?>(
      valueListenable: currentUser,
      builder: (context, user, child) {
        return Padding(
          padding: const EdgeInsets.all(20.0),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 50),
                const Text(
                  "궁금한 장소를 물어보세요!",
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 30),
                TextField(
                  controller: _titleController,
                  decoration: const InputDecoration(
                    labelText: "제목",
                    hintText: "예: 붕어빵 아저씨 오셨나요?",
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  height: 150, // 내용 입력창 높이
                  child: TextField(
                    controller: _contentController,
                    maxLines: null, // 여러 줄 입력
                    expands: true,
                    textAlignVertical: TextAlignVertical.top,
                    decoration: const InputDecoration(
                      labelText: "내용",
                      hintText: "궁금한 내용을 자세히 적어주세요.",
                      alignLabelWithHint: true,
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // 위치 입력 (지도 연동 + 아이콘 검색)
                GestureDetector(
                  onTap: () => _showAddressSearchDialog(),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _locationController,
                          enabled: false, // 터치로만 동작
                          decoration: const InputDecoration(
                            labelText: "위치",
                            hintText: "지도를 터치하거나 아이콘을 눌러 검색하세요",
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.location_on),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      IconButton(
                        onPressed: () => _showAddressSearchDialog(),
                        icon: const Icon(Icons.search, size: 30),
                        color: Colors.blue,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),

                // 지도 미리보기 (터치 잠금 기능 추가)
                Container(
                  height: 500,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Stack(
                      children: [
                        FlutterMap(
                          mapController: _mapController,
                          options: MapOptions(
                            initialCenter: _selectedLocation,
                            initialZoom: 16.0,
                            onTap: (tapPos, point) {
                              // 지도 활성화 상태에서만 핀 이동
                              if (_isMapInteractive) {
                                _onMapTap(tapPos, point);
                              }
                            },
                            interactionOptions: InteractionOptions(
                              flags: _isMapInteractive
                                  ? InteractiveFlag.all
                                  : InteractiveFlag.none,
                            ),
                          ),
                          children: [
                            TileLayer(
                              urlTemplate:
                                  'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                              userAgentPackageName: 'com.example.app',
                            ),
                            MarkerLayer(markers: _markers),
                          ],
                        ),
                        if (!_isMapInteractive)
                          GestureDetector(
                            onTap: () {
                              setState(() {
                                _isMapInteractive = true;
                              });
                            },
                            behavior: HitTestBehavior.translucent,
                            child: Container(
                              width: double.infinity,
                              height: double.infinity,
                              color: Colors.black.withOpacity(0.1),
                              alignment: Alignment.center,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.9),
                                  borderRadius: BorderRadius.circular(20),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black26,
                                      blurRadius: 4,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.touch_app, size: 24),
                                    SizedBox(width: 8),
                                    Text(
                                      "지도를 조작하려면 터치하세요",
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 30),

                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: () {
                      if (user == null) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const LoginScreen(),
                          ),
                        );
                      } else {
                        if (_titleController.text.isEmpty ||
                            _contentController.text.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text("제목과 내용을 입력해주세요.")),
                          );
                          return;
                        }
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text("질문이 등록되었습니다!")),
                        );
                        // 초기화
                        setState(() {
                          _titleController.clear();
                          _contentController.clear();
                          // 위치는 리셋 (편의성)
                          _selectedLocation = const LatLng(37.5973, 127.0583);
                          _updateMarker(_selectedLocation);
                          _reverseGeocode(_selectedLocation);
                        });
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: user != null ? null : Colors.grey,
                      foregroundColor: user != null ? null : Colors.white,
                    ),
                    child: Text(
                      user != null ? "질문 등록하기" : "로그인하고 질문 등록하기",
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 50),
              ],
            ),
          ),
        );
      },
    );
  }
}

// --- 미션 수행 (Camera Screen) ---
class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  bool _isProcessing = false;
  bool _isUploaded = false;

  void _takePhoto() {
    setState(() {
      _isProcessing = true;
    });

    // AI 블러 처리 시뮬레이션 (2초 대기)
    Timer(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _isUploaded = true;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("미션 수행 (촬영)")),
      body: Center(
        child: _isUploaded
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.check_circle, color: Colors.green, size: 80),
                  const SizedBox(height: 20),
                  const Text(
                    "전송 완료!",
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const Text(
                    "AI가 얼굴을 자동으로 가렸습니다.",
                    style: TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context), // 완료 후 뒤로가기
                    child: const Text("지도 화면으로 복귀"),
                  ),
                ],
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 300,
                    height: 300,
                    color: Colors.black12,
                    child: _isProcessing
                        ? const Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              CircularProgressIndicator(),
                              SizedBox(height: 20),
                              Text(
                                "AI가 얼굴을 블러 처리 중입니다...",
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ],
                          )
                        : const Icon(
                            Icons.camera_alt,
                            size: 100,
                            color: Colors.grey,
                          ),
                  ),
                  const SizedBox(height: 30),
                  ElevatedButton.icon(
                    onPressed: _isProcessing ? null : _takePhoto,
                    icon: const Icon(Icons.camera),
                    label: const Text("실시간 촬영하기 (갤러리 불가)"),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 30,
                        vertical: 15,
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

// --- 3. 응모 뷰 (Apply View) ---
// --- 3. 응모 뷰 (Apply View: Weekly Event) ---
// --- 3. 응모 뷰 (Apply View: Weekly Event) ---
class ApplyView extends StatefulWidget {
  const ApplyView({super.key});

  @override
  State<ApplyView> createState() => _ApplyViewState();
}

class _ApplyViewState extends State<ApplyView> {
  Timer? _timer;
  String _timeLeft = "00:00:00";

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    _updateTime();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _updateTime();
    });
  }

  void _updateTime() {
    final now = DateTime.now();
    // 다음 주 월요일 00:00 계산
    // 1(월)..7(일). 다음 월요일은?
    // (8 - weekday) % 7 days later? No.
    // Monday(1) -> Next Monday(+7)
    // Sunday(7) -> Next Monday(+1)

    int daysUntilMonday = 8 - now.weekday;
    if (daysUntilMonday == 0) daysUntilMonday = 7; // 오늘이 월요일 00:00 지났으면 다음주

    // 타겟: 이번주 일요일 자정 = 다음주 월요일 00:00
    // 그냥 다음 돌아오는 월요일 00:00으로 설정
    // 만약 오늘이 월요일이고 00:00:01이면? 다음주 월요일로.

    final nextMonday = DateTime(now.year, now.month, now.day + daysUntilMonday);
    // 정확히 00:00:00
    final target = DateTime(nextMonday.year, nextMonday.month, nextMonday.day);

    final difference = target.difference(now);

    if (difference.isNegative) {
      // 이미 지났으면(그럴 리 적지만) 0 처리
      if (mounted) setState(() => _timeLeft = "마감됨");
    } else {
      final days = difference.inDays;
      final hours = difference.inHours % 24;
      final minutes = difference.inMinutes % 60;
      final seconds = difference.inSeconds % 60;

      // 포맷: D-Day HH:MM:SS or just HH:MM:SS if < 24h
      // 요청: "몇분 몇초 남았다는 타이머" -> Detail Time
      String formatted = "";
      if (days > 0) formatted += "${days}일 ";
      formatted +=
          "${hours.toString().padLeft(2, '0')}:"
          "${minutes.toString().padLeft(2, '0')}:"
          "${seconds.toString().padLeft(2, '0')}";

      if (mounted) setState(() => _timeLeft = formatted);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<UserModel?>(
      valueListenable: currentUser,
      builder: (context, user, child) {
        return Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 50),
              const Text(
                "🎁 12월 5주차 주간 이벤트",
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              const Text(
                "한 주 동안 열심히 활동한 당신, 선물 받아가세요!",
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
              const SizedBox(height: 30),

              // 경품 카드 (누구나 볼 수 있음)
              Card(
                elevation: 8,
                shadowColor: Colors.black26,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(30.0),
                  child: Column(
                    children: [
                      Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.headphones,
                          size: 70,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        "AirPods Pro 2세대",
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        "압도적인 노이즈 캔슬링과\n풍성한 사운드를 경험하세요.",
                        style: TextStyle(fontSize: 14, color: Colors.grey),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 20),
                      // 타이머 표시
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 15,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.redAccent.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.timer,
                              size: 16,
                              color: Colors.redAccent,
                            ),
                            const SizedBox(width: 5),
                            Text(
                              "남은 시간: $_timeLeft",
                              style: const TextStyle(
                                color: Colors.redAccent,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 15),
              // 총 응모권 수 (누구나 볼 수 있음)
              const Center(
                child: Text(
                  "현재까지 누적된 총 응모권: 2,543장",
                  style: TextStyle(
                    color: Colors.grey,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),

              const Spacer(),

              // 보유 티켓 정보 (로그인 시에만 개수 표시)
              Container(
                padding: const EdgeInsets.symmetric(
                  vertical: 15,
                  horizontal: 20,
                ),
                decoration: BoxDecoration(
                  color: Colors.blue[50], // 연한 블루 배경
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(color: Colors.blue.withOpacity(0.3)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      "🎟 나의 보유 응모권",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      user != null ? "${user.tickets}장" : "로그인 필요",
                      style: TextStyle(
                        fontSize: user != null ? 24 : 16,
                        fontWeight: FontWeight.bold,
                        color: user != null ? Colors.blue : Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              SizedBox(
                height: 55,
                child: ElevatedButton(
                  onPressed: () {
                    if (user == null) {
                      // 비로그인 -> 로그인 화면으로 이동
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const LoginScreen(),
                        ),
                      );
                    } else {
                      // 로그인 -> 응모 로직
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("🎉 응모 완료! (당첨을 기원합니다)")),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: user != null
                        ? Colors.blueAccent
                        : Colors.grey,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                    elevation: 2,
                  ),
                  child: Text(
                    user != null ? "응모권 1장으로 응모하기" : "로그인하고 응모하기",
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }
}

// --- 4. 마이페이지 (My Page) ---
// --- 4. 마이페이지 (My Page) ---
class MyPageView extends StatelessWidget {
  const MyPageView({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<UserModel?>(
      valueListenable: currentUser,
      builder: (context, user, child) {
        if (user == null) {
          // 비로그인 상태 UI
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.location_on, // Pinda PIN
                  size: 80,
                  color: Colors.blueAccent,
                ),
                const SizedBox(height: 20),
                const Text(
                  "Pinda",
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  "지금 여기, 궁금한 곳의 모든 것",
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                ),
                const SizedBox(height: 60),

                // 아이디로 회원가입 버튼
                InkWell(
                  onTap: () {
                    // 모의 로그인 처리
                    currentUser.value = UserModel(
                      nickname: "순대감별사",
                      level: 3,
                      tickets: 5,
                    );
                  },
                  child: Container(
                    width: double.infinity,
                    height: 50,
                    decoration: BoxDecoration(
                      color: Colors.blueAccent,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Center(
                      child: Text(
                        "아이디로 회원가입",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 15),

                // 카카오 로그인 버튼 (Mock)
                InkWell(
                  onTap: () {
                    // 모의 로그인 처리
                    currentUser.value = UserModel(
                      nickname: "순대감별사",
                      level: 3,
                      tickets: 5,
                    );
                  },
                  child: Container(
                    width: double.infinity,
                    height: 50,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEE500),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.chat_bubble,
                          color: Colors.black87,
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        const Text(
                          "카카오로 3초만에 시작하기",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 15),

                // 구글 로그인 버튼 (Mock)
                InkWell(
                  onTap: () {
                    // 모의 로그인 처리
                    currentUser.value = UserModel(
                      nickname: "순대감별사",
                      level: 3,
                      tickets: 5,
                    );
                  },
                  child: Container(
                    width: double.infinity,
                    height: 50,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.g_mobiledata,
                          color: Colors.black87,
                          size: 30,
                        ),
                        const SizedBox(width: 5),
                        const Text(
                          "Google로 계속하기",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 15),

                // Apple 로그인 버튼 (Mock)
                InkWell(
                  onTap: () {
                    // 모의 로그인 처리
                    currentUser.value = UserModel(
                      nickname: "순대감별사",
                      level: 3,
                      tickets: 5,
                    );
                  },
                  child: Container(
                    width: double.infinity,
                    height: 50,
                    decoration: BoxDecoration(
                      color: Colors.black, // Apple Black
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.phone_iphone, // Apple logo fallback
                          color: Colors.white,
                          size: 24,
                        ),
                        SizedBox(width: 5),
                        Text(
                          "Apple로 계속하기",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        // 로그인 상태 UI (기존 코드 유지 및 데이터 연동)
        return Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 40),
              Row(
                children: [
                  const CircleAvatar(
                    radius: 40,
                    backgroundColor: Colors.blueAccent,
                    child: Icon(Icons.person, size: 50, color: Colors.white),
                  ),
                  const SizedBox(width: 20),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "${user.nickname} 님",
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        "LV.${user.level} 동네 보안관",
                        style: const TextStyle(
                          color: Colors.blue,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 30),
              const Text(
                "나의 경험치 (다음 레벨까지 30%)",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              const LinearProgressIndicator(
                value: 0.7,
                backgroundColor: Colors.grey,
                color: Colors.blue,
                minHeight: 10,
              ),
              const SizedBox(height: 30),
              const Text(
                "🏆 획득한 배지",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 15),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildBadge(Icons.star, "첫 답변", Colors.yellow),
                  _buildBadge(
                    Icons.local_fire_department,
                    "핫플 마스터",
                    Colors.red,
                  ),
                  _buildBadge(Icons.verified, "신뢰도 100%", Colors.green),
                ],
              ),
              const Spacer(),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  children: [
                    const Text("🎟 보유한 응모권", style: TextStyle(fontSize: 16)),
                    Text(
                      "${user.tickets}장",
                      style: const TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                    ),
                    const Text(
                      "이번 주 1등 상품: 에어팟 프로 2",
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              // 로그아웃 버튼 추가
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () {
                    currentUser.value = null; // 로그아웃
                  },
                  child: const Text("로그아웃"),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBadge(IconData icon, String label, Color color) {
    return Column(
      children: [
        CircleAvatar(
          radius: 30,
          backgroundColor: color.withOpacity(0.2),
          child: Icon(icon, color: color, size: 30),
        ),
        const SizedBox(height: 5),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }
}

// --- 로그인 화면 (Login Screen) ---
class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  void _performLogin(BuildContext context) {
    // 모의 로그인 처리
    currentUser.value = UserModel(nickname: "순대감별사", level: 3, tickets: 5);
    Navigator.pop(context); // 이전 화면으로 복귀
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.location_on, size: 80, color: Colors.blueAccent),
            const SizedBox(height: 20),
            const Text(
              "Pinda",
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              "지금 여기, 궁금한 곳의 모든 것",
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
            const SizedBox(height: 60),

            // 아이디로 회원가입 버튼
            InkWell(
              onTap: () => _performLogin(context),
              child: Container(
                width: double.infinity,
                height: 50,
                decoration: BoxDecoration(
                  color: Colors.blueAccent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Center(
                  child: Text(
                    "아이디로 회원가입",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 15),

            // 카카오 로그인 버튼 (Mock)
            InkWell(
              onTap: () => _performLogin(context),
              child: Container(
                width: double.infinity,
                height: 50,
                decoration: BoxDecoration(
                  color: const Color(0xFFFEE500),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.chat_bubble,
                      color: Colors.black87,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    const Text(
                      "카카오로 3초만에 시작하기",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 15),

            // 구글 로그인 버튼 (Mock)
            InkWell(
              onTap: () => _performLogin(context),
              child: Container(
                width: double.infinity,
                height: 50,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.g_mobiledata,
                      color: Colors.black87,
                      size: 30,
                    ),
                    const SizedBox(width: 5),
                    const Text(
                      "Google로 계속하기",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 15),

            // Apple 로그인 버튼 (Mock)
            InkWell(
              onTap: () => _performLogin(context),
              child: Container(
                width: double.infinity,
                height: 50,
                decoration: BoxDecoration(
                  color: Colors.black, // Apple Black
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.phone_iphone, // Apple logo fallback
                      color: Colors.white,
                      size: 24,
                    ),
                    SizedBox(width: 5),
                    Text(
                      "Apple로 계속하기",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
