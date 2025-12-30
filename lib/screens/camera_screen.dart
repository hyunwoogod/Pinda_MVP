import 'package:flutter/material.dart';
import 'dart:async';

// --- 카메라 모의 화면 (Camera Screen) ---
class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  // AI 분석 시뮬레이션
  bool _isProcessing = false;

  void _takePhoto() {
    setState(() {
      _isProcessing = true;
    });

    // 3초 후 분석 완료
    Timer(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
        // 결과 반환
        Navigator.pop(context, "success");
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          const Center(
            child: Icon(Icons.camera_alt, size: 100, color: Colors.grey),
          ),
          if (_isProcessing)
            Container(
              color: Colors.black54,
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 20),
                    Text(
                      "AI가 사진을 분석 중입니다...",
                      style: TextStyle(color: Colors.white, fontSize: 18),
                    ),
                  ],
                ),
              ),
            ),
          Positioned(
            bottom: 50,
            left: 0,
            right: 0,
            child: Center(
              child: GestureDetector(
                onTap: _takePhoto,
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.grey, width: 4),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            top: 50,
            left: 20,
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.white, size: 30),
              onPressed: () => Navigator.pop(context),
            ),
          ),
        ],
      ),
    );
  }
}
