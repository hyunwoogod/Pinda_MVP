import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../widgets/naver_map_web.dart';
import 'camera_screen.dart';
import '../models/user_model.dart';
import 'login_screen.dart';
import '../state/question_state.dart';

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

  double? _currentLat;
  double? _currentLng;

  @override
  void initState() {
    super.initState();
    _checkPermission();
    QuestionState().addListener(_onQuestionsChanged);
  }

  @override
  void dispose() {
    QuestionState().removeListener(_onQuestionsChanged);
    super.dispose();
  }

  void _onQuestionsChanged() {
    // 새 질문이 추가되면 마지막 질문 위치로 이동
    final questions = QuestionState().value;
    if (questions.isNotEmpty && _mapController != null) {
      final lastQ = questions.last;
      // 탭 전환 애니메이션 등을 고려하여 약간 지연 후 이동
      Future.delayed(const Duration(milliseconds: 500), () {
        _mapController?.moveCamera(lastQ.latitude, lastQ.longitude);
        // 카테고리 캡션이 잘 보이도록 줌 레벨 조정 등 가능
      });
    }
  }

  Future<void> _checkPermission() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
  }

  Future<void> _moveToCurrentLocation() async {
    try {
      Position position = await Geolocator.getCurrentPosition();
      setState(() {
        _currentLat = position.latitude;
        _currentLng = position.longitude;
      });
      _mapController?.moveCamera(position.latitude, position.longitude);
    } catch (e) {
      debugPrint("Location error: $e");
    }
  }

  String _timeAgo(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inMinutes < 1) return "방금 전";
    if (diff.inMinutes < 60) return "${diff.inMinutes}분 전";
    if (diff.inHours < 24) return "${diff.inHours}시간 전";
    return "${diff.inDays}일 전";
  }

  void _showQuestionDetail(Question q) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.5,
          minChildSize: 0.3,
          maxChildSize: 0.9,
          builder: (context, scrollController) {
            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: SingleChildScrollView(
                controller: scrollController,
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 상단 핸들
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // 카테고리 & 시간 & 제목
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.red[50],
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            q.category,
                            style: const TextStyle(
                                color: Colors.red, fontSize: 12),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _timeAgo(q.createdAt),
                          style:
                              const TextStyle(color: Colors.grey, fontSize: 12),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      q.title,
                      style: const TextStyle(
                          fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      q.content,
                      style: const TextStyle(fontSize: 16),
                    ),
                    const SizedBox(height: 20),
                    const Divider(),
                    const SizedBox(height: 10),

                    // 댓글 섹션
                    Text("댓글 ${q.comments.length}",
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 10),

                    if (q.comments.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(20.0),
                        child: Center(child: Text("아직 댓글이 없습니다.")),
                      )
                    else
                      ...q.comments.map((c) => Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const CircleAvatar(
                                  radius: 12,
                                  backgroundColor: Colors.grey,
                                  child: Icon(Icons.person,
                                      size: 16, color: Colors.white),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Text(c.author,
                                              style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 13)),
                                          const SizedBox(width: 6),
                                          Text(_timeAgo(c.createdAt),
                                              style: const TextStyle(
                                                  color: Colors.grey,
                                                  fontSize: 11)),
                                        ],
                                      ),
                                      const SizedBox(height: 2),
                                      Text(c.content),
                                    ],
                                  ),
                                ),
                                // 질문 작성자만 볼 수 있는 채택(해결) 버튼
                                if (currentUser.value?.nickname == q.author)
                                  IconButton(
                                    icon: const Icon(Icons.check_circle_outline,
                                        color: Colors.green),
                                    onPressed: () {
                                      showDialog(
                                        context: context,
                                        builder: (context) => AlertDialog(
                                          title: const Text("답변 채택"),
                                          content: const Text(
                                              "이 답변으로 문제를 해결하시겠습니까?\n채택 시 질문 핀이 지도에서 사라집니다."),
                                          actions: [
                                            TextButton(
                                              onPressed: () =>
                                                  Navigator.pop(context),
                                              child: const Text("취소"),
                                            ),
                                            ElevatedButton(
                                              onPressed: () async {
                                                await QuestionState()
                                                    .deleteQuestion(q.id);
                                                if (mounted) {
                                                  Navigator.pop(
                                                      context); // Dialog
                                                  Navigator.pop(
                                                      context); // BottomSheet
                                                  ScaffoldMessenger.of(context)
                                                      .showSnackBar(
                                                    const SnackBar(
                                                        content: Text(
                                                            "해결되었습니다! 핀이 삭제됩니다.")),
                                                  );
                                                }
                                              },
                                              child: const Text("채택 및 해결"),
                                            ),
                                          ],
                                        ),
                                      );
                                    },
                                  ),
                              ],
                            ),
                          )),

                    // 하단 답변하기 버튼 (UI유지)
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () async {
                          // 로그인 체크
                          if (currentUser.value == null) {
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text("로그인이 필요한 서비스입니다.")),
                            );
                            Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) => const LoginScreen()));
                            return;
                          }

                          Navigator.pop(context); // 시트 닫기
                          final result = await Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (context) => const CameraScreen()),
                          );

                          if (result != null && result is String) {
                            if (mounted) _showCommentInput(q, result);
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text("답변하기 (사진 촬영)"),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false, // 키보드 올라와도 맵 크기 줄어들지 않게 고정
      body: Stack(
        children: [
          SizedBox.expand(
            child: ValueListenableBuilder<List<Question>>(
              valueListenable: QuestionState(),
              builder: (context, questions, child) {
                return NaverMapWeb(
                  latitude: _initialLat,
                  longitude: _initialLng,
                  zoom: 14,
                  markers: [
                    ...questions.map((q) => NaverMapMarker(
                          id: q.id,
                          latitude: q.latitude,
                          longitude: q.longitude,
                          title: q.title,
                          captionText: q.category,
                          onTap: () => _showQuestionDetail(q),
                        )),
                    if (_currentLat != null && _currentLng != null)
                      NaverMapMarker(
                        id: 'my_location',
                        latitude: _currentLat!,
                        longitude: _currentLng!,
                        title: '내 위치',
                        isMyLocation: true,
                      ),
                  ],
                  onMapReady: (controller) {
                    _mapController = controller;
                  },
                );
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

          // 내 위치 버튼
          Positioned(
            bottom: 20,
            right: 20,
            child: FloatingActionButton(
              onPressed: _moveToCurrentLocation,
              backgroundColor: Colors.white,
              foregroundColor: Colors.red,
              elevation: 4,
              shape: const CircleBorder(),
              child: const Icon(Icons.my_location),
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
          // autofocus: true, // 모바일 키보드 호환성 수정
          textInputAction: TextInputAction.search,
          decoration: const InputDecoration(
            hintText: "주소 입력",
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

  void _showCommentInput(Question q, String imagePath) {
    final commentController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("답변 작성"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              height: 150,
              width: double.infinity,
              color: Colors.grey[300],
              child: const Icon(Icons.image, size: 50, color: Colors.white),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: commentController,
              decoration: const InputDecoration(
                hintText: "상황을 설명해주세요",
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context), child: const Text("취소")),
          ElevatedButton(
            onPressed: () {
              if (commentController.text.isEmpty) return;

              final newComment = Comment(
                id: "c_${DateTime.now().millisecondsSinceEpoch}",
                content: commentController.text,
                author: currentUser.value?.nickname ?? "익명",
                createdAt: DateTime.now(),
              );

              QuestionState().addComment(q.id, newComment);
              Navigator.pop(context);

              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("답변이 등록되었습니다!")),
              );

              // 갱신된 정보로 다시 상세창 열기
              final updatedQ = QuestionState()
                  .value
                  .firstWhere((e) => e.id == q.id, orElse: () => q);
              _showQuestionDetail(updatedQ);
            },
            child: const Text("등록"),
          ),
        ],
      ),
    );
  }
}
