import 'package:flutter/material.dart';
import 'dart:async'; // AI 처리 시간 시뮬레이션용
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';

void main() {
  runApp(const PindaApp());
}

class PindaApp extends StatelessWidget {
  const PindaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Pinda',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
        scaffoldBackgroundColor: Colors.grey[50], // 눈이 편안한 배경색
      ),
      home: const MainScreen(),
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;

  // 화면 3개: 지도(Map), 촬영(Camera), 마이페이지(MyPage)
  static final List<Widget> _widgetOptions = <Widget>[
    const MapView(), // 1. 지도 뷰
    const CameraView(), // 2. AI 카메라 뷰
    const MyPageView(), // 3. 마이페이지
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          '핀다(Pinda)',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: _widgetOptions.elementAt(_selectedIndex),
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(icon: Icon(Icons.map), label: '지도'),
          BottomNavigationBarItem(icon: Icon(Icons.camera_alt), label: '촬영'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: '내 정보'),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.blue,
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

  // 초기 카메라 위치 (서울 시청) - OSM은 LatLng 사용 방법이 다름 (latlong2 패키지)
  static const LatLng _kSeoul = LatLng(37.5665, 126.9780);

  // 마커 목록 (MarkerLayer에 들어갈 Marker 위젯 리스트)
  List<Marker> _markers = [];
  LatLng? _currentPosition;

  @override
  void initState() {
    super.initState();
    _checkPermissionAndFetchLocation();
    _initMarkers();
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

  Future<void> _checkPermissionAndFetchLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('위치 서비스가 비활성화되어 있습니다.')));
      return;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        if (mounted)
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('위치 권한이 거부되었습니다.')));
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('위치 권한이 영구적으로 거부되었습니다.')));
      return;
    }

    Position position = await Geolocator.getCurrentPosition();
    setState(() {
      _currentPosition = LatLng(position.latitude, position.longitude);
    });
    _mapController.move(_currentPosition!, 16.0);
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
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("촬영 탭으로 이동하여 미션을 수행하세요!")),
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
      body: FlutterMap(
        mapController: _mapController,
        options: MapOptions(
          initialCenter: _kSeoul,
          initialZoom: 14.0,
          interactionOptions: const InteractionOptions(
            flags:
                InteractiveFlag.all & ~InteractiveFlag.rotate, // 회전 비활성화 (선택사항)
          ),
        ),
        children: [
          TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'com.example.app', // 중요: OSM 정책상 식별자 필요
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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _checkPermissionAndFetchLocation,
        label: const Text('내 위치로'),
        icon: const Icon(Icons.my_location),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}

// --- 2. 촬영 뷰 (Camera View + AI Logic) ---
class CameraView extends StatefulWidget {
  const CameraView({super.key});

  @override
  State<CameraView> createState() => _CameraViewState();
}

class _CameraViewState extends State<CameraView> {
  bool _isProcessing = false;
  bool _isUploaded = false;

  void _takePhoto() {
    setState(() {
      _isProcessing = true;
    });

    // AI 블러 처리 시뮬레이션 (2초 대기)
    Timer(const Duration(seconds: 2), () {
      setState(() {
        _isProcessing = false;
        _isUploaded = true;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Center(
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
                  onPressed: () => setState(() {
                    _isUploaded = false;
                  }),
                  child: const Text("다른 미션 수행하기"),
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
    );
  }
}

// --- 3. 마이페이지 (My Page + Gamification) ---
class MyPageView extends StatelessWidget {
  const MyPageView({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              CircleAvatar(
                radius: 40,
                backgroundColor: Colors.blueAccent,
                child: Icon(Icons.person, size: 50, color: Colors.white),
              ),
              SizedBox(width: 20),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "순대감별사 님",
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    "LV.3 동네 보안관",
                    style: TextStyle(
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
              _buildBadge(Icons.local_fire_department, "핫플 마스터", Colors.red),
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
            child: const Column(
              children: [
                Text("🎟 보유한 응모권", style: TextStyle(fontSize: 16)),
                Text(
                  "5장",
                  style: TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue,
                  ),
                ),
                Text(
                  "이번 주 1등 상품: 에어팟 프로 2",
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
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
