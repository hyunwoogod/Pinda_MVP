import 'package:flutter/material.dart';
import '../widgets/naver_map_web.dart';
import '../models/user_model.dart';
import 'login_screen.dart';

// --- 2. 질문 뷰 (Question View) ---
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
  NaverMapWebController? _mapController;
  double _selectedLat = 37.5973;
  double _selectedLng = 127.0583;
  bool _isMapInteractive = false;

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  void _onMapTap(double lat, double lng) {
    if (!_isMapInteractive) return;

    setState(() {
      _selectedLat = lat;
      _selectedLng = lng;
    });

    // 마커 업데이트
    _mapController?.updateMarkers([
      NaverMapMarker(
        id: 'selected',
        latitude: lat,
        longitude: lng,
      ),
    ]);

    // 역지오코딩 (네이버 API 사용)
    _reverseGeocode(lat, lng);
  }

  Future<void> _reverseGeocode(double lat, double lng) async {
    try {
      final address = await NaverGeocodingService.reverseGeocode(lat, lng);
      if (mounted && address != null) {
        setState(() {
          _locationController.text = address;
        });
      }
    } catch (e) {
      debugPrint('Reverse geocode error: $e');
    }
  }

  Future<List<NaverGeocodingResult>> _fetchLocations(String query) async {
    if (query.isEmpty) return [];
    try {
      return await NaverGeocodingService.geocode(query);
    } catch (e) {
      debugPrint('Location search error: $e');
    }
    return [];
  }

  void _showSearchDialog() {
    final searchController = TextEditingController();
    List<NaverGeocodingResult> results = [];

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text("위치 검색"),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: searchController,
                  decoration: const InputDecoration(
                    hintText: "주소 입력",
                    border: OutlineInputBorder(),
                    suffixIcon: Icon(Icons.search),
                  ),
                  onSubmitted: (value) async {
                    final locations = await _fetchLocations(value);
                    setDialogState(() {
                      results = locations;
                    });
                  },
                ),
                const SizedBox(height: 10),
                if (results.isNotEmpty)
                  SizedBox(
                    height: 200,
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: results.length,
                      itemBuilder: (context, index) {
                        final item = results[index];
                        return ListTile(
                          title: Text(
                            item.address,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          onTap: () {
                            Navigator.pop(context);
                            _selectLocation(
                              item.latitude,
                              item.longitude,
                              item.address,
                            );
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
        ),
      ),
    );
  }

  void _selectLocation(double lat, double lng, String address) {
    setState(() {
      _selectedLat = lat;
      _selectedLng = lng;
      _locationController.text = address;
    });

    // 지도 이동 및 마커 업데이트
    _mapController?.moveCamera(lat, lng, zoom: 16);
    _mapController?.updateMarkers([
      NaverMapMarker(
        id: 'selected',
        latitude: lat,
        longitude: lng,
      ),
    ]);
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
                  height: 150,
                  child: TextField(
                    controller: _contentController,
                    maxLines: null,
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
                  onTap: _showSearchDialog,
                  child: AbsorbPointer(
                    child: TextField(
                      controller: _locationController,
                      readOnly: true,
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

                // 지도 미리보기
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
                        SizedBox.expand(
                          child: NaverMapWeb(
                            latitude: _selectedLat,
                            longitude: _selectedLng,
                            zoom: 16,
                            markers: [
                              NaverMapMarker(
                                id: 'selected',
                                latitude: _selectedLat,
                                longitude: _selectedLng,
                              ),
                            ],
                            onMapReady: (controller) {
                              _mapController = controller;
                            },
                            onMapTapped: _isMapInteractive ? _onMapTap : null,
                          ),
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
