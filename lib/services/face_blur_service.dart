import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:image/image.dart' as img;

class FaceBlurService {
  // 싱글톤 패턴 (선택사항, 여기선 유틸리티 성격이 강함)
  static final FaceBlurService _instance = FaceBlurService._internal();
  factory FaceBlurService() => _instance;
  FaceBlurService._internal();

  final FaceDetector _faceDetector = FaceDetector(
    options: FaceDetectorOptions(
      enableContours: false,
      enableLandmarks: false,
      enableClassification: false,
      minFaceSize: 0.1, // 감지할 얼굴 최소 크기
      performanceMode: FaceDetectorMode.accurate,
    ),
  );

  /// 이미지 파일에서 얼굴을 감지하고 블러 처리한 후, 새로운 이미지 바이트를 반환합니다.
  Future<Uint8List?> blurFaces(File imageFile) async {
    try {
      // 1. Google ML Kit를 위한 InputImage 생성
      final inputImage = InputImage.fromFile(imageFile);

      // 2. 얼굴 감지
      final List<Face> faces = await _faceDetector.processImage(inputImage);

      if (faces.isEmpty) {
        // 얼굴이 없으면 원본 그대로 반환
        return await imageFile.readAsBytes();
      }

      // 3. 이미지 디코딩 (image 패키지 사용) 위한 바이트 로드
      final imageBytes = await imageFile.readAsBytes();
      final img.Image? originalImage = img.decodeImage(imageBytes);

      if (originalImage == null) return null;

      // 4. 감지된 각 얼굴 영역에 블러 적용
      for (final face in faces) {
        final rect = face.boundingBox;

        // 좌표 보정 (이미지 범위 내로 제한)
        int x = max(0, rect.left.toInt());
        int y = max(0, rect.top.toInt());
        int w = min(originalImage.width - x, rect.width.toInt());
        int h = min(originalImage.height - y, rect.height.toInt());

        // Gaussian Blur 등을 직접 적용하거나, Pixelate(모자이크) 적용
        // 여기서는 성능과 스타일을 위해 '픽셀레이트(모자이크)' 효과를 적용합니다.
        // blur 기능은 image 패키지 버전에 따라 다를 수 있으므로 안전하게 pixelate 권장.

        _applyPixelate(originalImage, x, y, w, h, blockSize: 15);
      }

      // 5. 결과 인코딩 (JPG)
      return Uint8List.fromList(img.encodeJpg(originalImage, quality: 85));
    } catch (e) {
      debugPrint("Face Blur Error: $e");
      return null;
    }
  }

  // 간단한 모자이크 처리 (Pixelate)
  void _applyPixelate(img.Image image, int x, int y, int w, int h,
      {int blockSize = 10}) {
    for (int py = y; py < y + h; py += blockSize) {
      for (int px = x; px < x + w; px += blockSize) {
        // 블록 내 평균 색상 구하기 (혹은 첫번째 픽셀 색상 사용)
        // 여기서는 가장 간단하게 블록의 첫 픽셀 색으로 덮기 (성능 최적화)

        // 범위 체크
        if (px >= image.width || py >= image.height) continue;

        final pixel = image.getPixel(px, py);

        // 블록 채우기
        for (int by = 0; by < blockSize; by++) {
          for (int bx = 0; bx < blockSize; bx++) {
            if (px + bx < x + w &&
                py + by < y + h &&
                px + bx < image.width &&
                py + by < image.height) {
              image.setPixel(px + bx, py + by, pixel);
            }
          }
        }
      }
    }
  }

  void dispose() {
    _faceDetector.close();
  }
}
