import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../models/user_model.dart';
import 'login_screen.dart';

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
    // _mapController.dispose(); // Flutter Map 6.x+
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
            offset: const Offset(0, -20), // 핀 끝이 지점에 닿도록 조정
            child: const Icon(Icons.location_on, color: Colors.red, size: 40),
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
                TextField(
                  controller: _locationController,
                  decoration: InputDecoration(
                    labelText: "위치",
                    hintText: "장소를 입력하고 엔터를 누르세요",
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.location_on),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.search, color: Colors.blue),
                      onPressed: () => _searchAddress(_locationController.text),
                    ),
                  ),
                  onSubmitted: (value) => _searchAddress(value),
                ),
                const SizedBox(height: 10),

                // 지도 미리보기 (터치 잠금 기능 추가)
                Container(
                  height: 300,
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
                                  boxShadow: const [
                                    BoxShadow(
                                      color: Colors.black26,
                                      blurRadius: 4,
                                      offset: Offset(0, 2),
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
                          _locationController.clear();
                        });
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          user == null ? Colors.grey : Colors.blueAccent,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      user == null ? "로그인하고 질문 등록하기" : "질문 등록하기",
                      style: const TextStyle(
                        fontSize: 18,
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
