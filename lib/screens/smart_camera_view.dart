import 'dart:io';
import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import '../services/face_blur_service.dart';

class SmartCameraView extends StatefulWidget {
  const SmartCameraView({super.key});

  @override
  State<SmartCameraView> createState() => _SmartCameraViewState();
}

class _SmartCameraViewState extends State<SmartCameraView> {
  CameraController? _controller;
  List<CameraDescription>? _cameras;
  bool _isInit = false;
  bool _isProcessing = false;

  // 결과 확인용
  Uint8List? _capturedImageBytes;

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  Future<void> _initCamera() async {
    try {
      _cameras = await availableCameras();
      if (_cameras != null && _cameras!.isNotEmpty) {
        // 후면 카메라 우선
        final backCamera = _cameras!.firstWhere(
            (c) => c.lensDirection == CameraLensDirection.back,
            orElse: () => _cameras!.first);

        _controller = CameraController(
          backCamera,
          ResolutionPreset.high,
          enableAudio: false,
        );

        await _controller!.initialize();
        if (mounted) {
          setState(() {
            _isInit = true;
          });
        }
      }
    } catch (e) {
      debugPrint("Camera Init Error: $e");
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _takePicture() async {
    if (_controller == null || !_controller!.value.isInitialized) return;
    if (_isProcessing) return;

    setState(() {
      _isProcessing = true;
    });

    try {
      // 1. 촬영
      final XFile rawImage = await _controller!.takePicture();

      // 2. AI 블러 처리 (FaceBlurService)
      final File imageFile = File(rawImage.path);
      final Uint8List? processedBytes =
          await FaceBlurService().blurFaces(imageFile);

      if (mounted) {
        setState(() {
          _capturedImageBytes = processedBytes;
          _isProcessing = false;
        });
      }

      // 임시 파일 정리 (선택사항)
      // imageFile.delete().ignore();
    } catch (e) {
      debugPrint("Capture/Process Error: $e");
      setState(() {
        _isProcessing = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("사진 처리 중 오류가 발생했습니다.")),
        );
      }
    }
  }

  void _retake() {
    setState(() {
      _capturedImageBytes = null;
    });
  }

  void _confirm() {
    if (_capturedImageBytes != null) {
      Navigator.pop(context, _capturedImageBytes);
    }
  }

  @override
  Widget build(BuildContext context) {
    // 1. 초기화 중일 때
    if (!_isInit || _controller == null) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator(color: Colors.red)),
      );
    }

    // 2. 결과 확인 화면 (블러된 이미지 프리뷰)
    if (_capturedImageBytes != null) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: Center(
                  child: Image.memory(
                    _capturedImageBytes!,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.all(20),
                color: Colors.black,
                child: Column(
                  children: [
                    const Text(
                      "✨ AI가 얼굴을 자동으로 가렸습니다.",
                      style: TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        TextButton.icon(
                          onPressed: _retake,
                          icon: const Icon(Icons.refresh, color: Colors.white),
                          label: const Text("다시 찍기",
                              style: TextStyle(color: Colors.white)),
                        ),
                        ElevatedButton.icon(
                          onPressed: _confirm,
                          icon: const Icon(Icons.check),
                          label: const Text("사용하기"),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 30, vertical: 12),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    // 3. 카메라 프리뷰 화면
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // 카메라 프리뷰 (전체 화면 채우기)
          Center(
            child: CameraPreview(_controller!),
          ),

          // 상단 안내 문구
          Positioned(
            top: 50,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  "얼굴과 번호판은 AI가 자동으로 가려줍니다 🤖",
                  style: TextStyle(color: Colors.white, fontSize: 13),
                ),
              ),
            ),
          ),

          // 닫기 버튼
          Positioned(
            top: 40,
            left: 10,
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.white, size: 30),
              onPressed: () => Navigator.pop(context),
            ),
          ),

          // 하단 셔터 버튼 영역
          Positioned(
            bottom: 30,
            left: 0,
            right: 0,
            child: Column(
              children: [
                if (_isProcessing)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 20),
                    child: Text("AI 처리중...",
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold)),
                  ),
                GestureDetector(
                  onTap: _takePicture,
                  child: Container(
                    width: 70,
                    height: 70,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 4),
                      color:
                          _isProcessing ? Colors.grey : Colors.red, // 처리중이면 회색
                    ),
                    child: _isProcessing
                        ? const CircularProgressIndicator(color: Colors.white)
                        : null,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
