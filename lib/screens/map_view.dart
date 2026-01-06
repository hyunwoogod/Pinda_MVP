import 'dart:async'; // Timer를 위해 추가
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../widgets/naver_map_web.dart';
import '../models/user_model.dart';

import 'dart:convert'; // Base64 decoding
import 'dart:typed_data';
// import 'package:image_picker/image_picker.dart'; // Deprecated for Answer
import 'smart_camera_view.dart';
import '../state/question_state.dart';

// --- 1. 지도 뷰 (Map View) ---
class MapView extends StatefulWidget {
  static final GlobalKey<MapViewState> globalKey = GlobalKey<MapViewState>();

  // 외부에서 초기 위치 지정 가능하도록 변경
  final double? initialLat;
  final double? initialLng;
  final double initialZoom;
  final String? districtName;

  const MapView({
    super.key,
    this.initialLat,
    this.initialLng,
    this.initialZoom = 14,
    this.districtName,
  });

  @override
  State<MapView> createState() => MapViewState();
}

class MapViewState extends State<MapView> {
  NaverMapWebController? _mapController;

  // 초기 카메라 위치 (서울 시청 기본값)
  late double _initialLat;
  late double _initialLng;
  late double _initialZoom;

  double? _currentLat;
  double? _currentLng;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    // 초기값 설정
    _initialLat = widget.initialLat ?? 37.5665;
    _initialLng = widget.initialLng ?? 126.9780;
    _initialZoom = widget.initialZoom;

    _checkPermission();
    QuestionState().addListener(_onQuestionsChanged);
    // 30초마다 화면 갱신 (마커 타이머 업데이트)
    _timer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
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

    if (permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse) {
      _moveToCurrentLocation(); // 권한 있으면 바로 내 위치로 이동
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
                                      if (c.imageBase64 != null) ...[
                                        const SizedBox(height: 8),
                                        ClipRRect(
                                          borderRadius:
                                              BorderRadius.circular(12),
                                          child: Image.memory(
                                            base64Decode(c.imageBase64!),
                                            width: double.infinity,
                                            height: 200,
                                            fit: BoxFit.cover,
                                            errorBuilder:
                                                (context, error, stackTrace) {
                                              return Container(
                                                  height: 200,
                                                  color: Colors.grey[200],
                                                  child: const Center(
                                                      child: Icon(Icons.error,
                                                          color: Colors.red)));
                                            },
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                      ],
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
                                      if (q.resolvedAt != null)
                                        return; // 이미 해결됨

                                      showDialog(
                                        context: context,
                                        builder: (context) => AlertDialog(
                                          title: const Text("답변 채택"),
                                          content: Text(
                                              "'${c.author}'님의 답변을 채택하시겠습니까?\n\n- 답변자에게 랭킹 점수 1점이 지급됩니다. 🏆\n- 이 질문은 해결됨 상태로 변경되며, 5분 뒤 지도에서 자동 삭제됩니다."),
                                          actions: [
                                            TextButton(
                                              onPressed: () =>
                                                  Navigator.pop(context),
                                              child: const Text("취소"),
                                            ),
                                            ElevatedButton(
                                              onPressed: () async {
                                                try {
                                                  await QuestionState()
                                                      .resolveQuestion(
                                                          q.id, c.author);
                                                  if (mounted) {
                                                    Navigator.pop(
                                                        context); // Dialog
                                                    Navigator.pop(
                                                        context); // BottomSheet
                                                    ScaffoldMessenger.of(
                                                            context)
                                                        .showSnackBar(
                                                      const SnackBar(
                                                          content: Text(
                                                              "채택되었습니다! 5분 뒤 핀이 삭제됩니다.")),
                                                    );
                                                  }
                                                } catch (e) {
                                                  if (mounted) {
                                                    ScaffoldMessenger.of(
                                                            context)
                                                        .showSnackBar(
                                                      SnackBar(
                                                          content: Text(
                                                              "오류 발생: $e")),
                                                    );
                                                  }
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
                    const SizedBox(height: 20),
                    // 수정된 답변하기 버튼 (다이얼로그 직접 호출)
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.camera_alt),
                        label: const Text("사진 찍고 답변하기"),
                        onPressed: () async {
                          // 로그인 체크
                          if (currentUser.value == null) {
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text("로그인이 필요한 서비스입니다.")),
                            );
                            Navigator.pop(context); // 바텀시트 닫기
                            return;
                          }
                          // 바로 카메라 실행
                          _startCameraAnswer(q);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
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
      appBar: widget.districtName != null
          ? AppBar(
              title: Text("${widget.districtName} 상세 지도"),
              backgroundColor: Colors.white,
              foregroundColor: Colors.black,
              elevation: 0,
            )
          : null, // 메인 탭일 때는 상위에서 처리하거나 없음
      body: Stack(
        children: [
          SizedBox.expand(
            child: ValueListenableBuilder<List<Question>>(
              valueListenable: QuestionState(),
              builder: (context, questions, child) {
                return NaverMapWeb(
                  latitude: _initialLat,
                  longitude: _initialLng,
                  zoom: _initialZoom,
                  markers: [
                    ...questions.map((q) {
                      String caption = q.category;
                      if (q.resolvedAt != null) {
                        final diff = DateTime.now().difference(q.resolvedAt!);
                        final remaining = 5 - diff.inMinutes;
                        if (remaining > 0) {
                          caption += " (삭제 예정: ${remaining}분전)";
                        } else {
                          caption += " (삭제 중...)";
                        }
                      }

                      return NaverMapMarker(
                        id: q.id,
                        latitude: q.latitude,
                        longitude: q.longitude,
                        title: q.title,
                        captionText: caption,
                        captionColor:
                            q.resolvedAt != null ? Colors.grey : Colors.black,
                        iconTintColor:
                            q.resolvedAt != null ? Colors.grey : Colors.red,
                        onTap: () => _showQuestionDetail(q),
                      );
                    }),
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

  Future<void> openQuestion(Question q) async {
    // 1. 카메라 이동 (줌 레벨 16으로 상세하게)
    if (_mapController != null) {
      _mapController!.moveCamera(q.latitude, q.longitude - 0.002,
          zoom: 16); // 오프셋 적용하여 마커가 보이는 위치로
    }
    // 2. 약간의 딜레이 후 상세창 표시 (지도 이동 애니메이션 고려)
    if (mounted) {
      // 기존 모달이 열려있다면 닫기
      if (Navigator.canPop(context)) {
        // Navigator.pop(context); // 이 부분은 사이드 이펙트가 클 수 있어 보류 (다른 다이얼로그일 수 있음)
      }
      _showQuestionDetail(q);
    }
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

  Future<void> _startCameraAnswer(Question q) async {
    // SmartCameraView로 이동하여 촬영 및 블러 처리된 이미지 받기
    final Uint8List? processedImage = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const SmartCameraView()),
    );

    if (processedImage != null && mounted) {
      _showPhotoCommentDialog(q, processedImage);
    }
  }

  // 사진 첨부 가능한 새로운 댓글 다이얼로그 (Camera Only + AI Blur)
  void _showPhotoCommentDialog(Question q, Uint8List initialImage) async {
    final commentController = TextEditingController();
    Uint8List? _webImageBytes = initialImage; // 이제 바로 바이트 사용

    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(builder: (context, setState) {
          // 다시 찍기 함수 (SmartCameraView 재호출)
          Future<void> _retakePhoto() async {
            // 현재 다이얼로그 숨기기 (임시) - 혹은 닫고 다시 열기
            // 여기선 Navigator push가 다이얼로그 위로 올라오므로 그대로 호출
            final Uint8List? processedImage = await Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const SmartCameraView()),
            );

            if (processedImage != null) {
              setState(() {
                _webImageBytes = processedImage;
              });
            }
          }

          return AlertDialog(
            title: const Text("답변 인증"),
            content: SizedBox(
              width: double.maxFinite,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 이미지 미리보기 영역
                  Container(
                    height: 250,
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(12),
                      image: _webImageBytes != null
                          ? DecorationImage(
                              image: MemoryImage(_webImageBytes!),
                              fit: BoxFit.cover,
                            )
                          : null,
                    ),
                    child: Stack(
                      children: [
                        // 다시 찍기 버튼 (우측 상단)
                        Positioned(
                          top: 10,
                          right: 10,
                          child: InkWell(
                            onTap: _retakePhoto,
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.6),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.refresh,
                                      color: Colors.white, size: 16),
                                  SizedBox(width: 4),
                                  Text("다시 찍기",
                                      style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold)),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 15),
                  const Text(
                    "🤖 AI가 얼굴을 자동으로 블러 처리했습니다.",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: Colors.green,
                        fontSize: 12,
                        fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 15),
                  TextField(
                    controller: commentController,
                    decoration: const InputDecoration(
                      hintText: "상황을 설명해주세요 (예: 지금 여기 자리 있어요!)",
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.all(12),
                    ),
                    maxLines: 2,
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("취소")),
              ElevatedButton(
                onPressed: () async {
                  if (_webImageBytes == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("사진 인증이 필요합니다.")),
                    );
                    return;
                  }

                  String base64Image = base64Encode(_webImageBytes!);

                  final text = commentController.text.trim().isEmpty
                      ? "사진 인증 답변입니다."
                      : commentController.text.trim();

                  final newComment = Comment(
                    id: "c_${DateTime.now().millisecondsSinceEpoch}",
                    content: text,
                    author: currentUser.value?.nickname ?? "익명",
                    createdAt: DateTime.now(),
                    imageBase64: base64Image,
                  );

                  await QuestionState().addComment(q.id, newComment);
                  if (context.mounted) Navigator.pop(context);

                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("인증 답변이 등록되었습니다! 📸")),
                    );
                  }
                },
                child: const Text("인증 완료"),
              ),
            ],
          );
        });
      },
    );
  }
}
