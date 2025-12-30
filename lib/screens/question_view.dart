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
    // 초기 위치 주소 자동완성 제거 (사용자가 직접 검색하도록 유도)
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

  // 장소 검색 API 호출 (결과 리스트 반환)
  Future<List<dynamic>> _fetchLocations(String query) async {
    if (query.isEmpty) return [];
    try {
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/search?q=$query&format=json&accept-language=ko&addressdetails=1&countrycodes=kr',
      );
      final response = await http.get(
        url,
        headers: {'User-Agent': 'NowHereApp/1.0'},
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
    } catch (e) {
      debugPrint("Search failed: $e");
    }
    return [];
  }

  // 검색 다이얼로그 표시
  void _showSearchDialog() {
    showDialog(
      context: context,
      builder: (context) {
        String query = "";
        List<dynamic> searchResults = [];
        bool isLoading = false;

        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: const Text("위치 검색"),
              content: SizedBox(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      autofocus: true,
                      decoration: const InputDecoration(
                        hintText: "주소 입력",
                        prefixIcon: Icon(Icons.search),
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (value) async {
                        query = value;
                        if (query.length < 2) return; // 2글자 이상일 때 검색

                        setStateDialog(() => isLoading = true);
                        final results = await _fetchLocations(query);

                        // 가나다 순 정렬 (display_name 기준)
                        results.sort((a, b) => (a['display_name'] as String)
                            .compareTo(b['display_name'] as String));

                        setStateDialog(() {
                          searchResults = results;
                          isLoading = false;
                        });
                      },
                    ),
                    const SizedBox(height: 10),
                    isLoading
                        ? const CircularProgressIndicator()
                        : SizedBox(
                            height: 300,
                            child: searchResults.isEmpty
                                ? const Center(child: Text("검색 결과가 여기에 표시됩니다."))
                                : ListView.builder(
                                    shrinkWrap: true,
                                    itemCount: searchResults.length,
                                    itemBuilder: (context, index) {
                                      final place = searchResults[index];
                                      return ListTile(
                                        title: Text(place['display_name']),
                                        leading: const Icon(Icons.location_on,
                                            color: Colors.grey),
                                        onTap: () {
                                          _selectLocation(place);
                                          Navigator.pop(context); // 다이얼로그 닫기
                                        },
                                      );
                                    },
                                  ),
                          ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("닫기"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // 장소 선택 처리
  void _selectLocation(Map<String, dynamic> place) {
    final lat = double.parse(place['lat']);
    final lon = double.parse(place['lon']);
    final displayName = place['display_name'];

    final newPoint = LatLng(lat, lon);
    _updateMarker(newPoint);

    setState(() {
      _locationController.text = displayName;
    });

    // 지도 이동 및 인터랙션 활성화
    _mapController.move(newPoint, 16.0);
    setState(() {
      _isMapInteractive = true;
    });
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

                // 위치 입력 (다이얼로그 팝업)
                GestureDetector(
                  onTap: _showSearchDialog, // 탭하면 검색창 뜸
                  child: AbsorbPointer(
                    // 텍스트 필드 자체 터치 막고 GestureDetector가 받음
                    child: TextField(
                      controller: _locationController,
                      readOnly: true, // 직접 입력 불가능
                      decoration: const InputDecoration(
                        labelText: "위치 검색",
                        hintText: "터치하여 장소를 검색하세요",
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.location_on),
                        suffixIcon: Icon(Icons.search, color: Colors.blue),
                      ),
                    ),
                  ),
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
                          user == null ? Colors.grey : Colors.lightBlue,
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
