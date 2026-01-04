import 'package:flutter/foundation.dart';

// --- 데이터 모델 & 상태 관리 ---
class UserModel {
  final String nickname;
  final String address; // 주소 추가
  final int level;
  final int tickets;
  final int acceptedCount; // 채택된 답변 수

  UserModel({
    required this.nickname,
    required this.address,
    required this.level,
    required this.tickets,
    this.acceptedCount = 0, // 기본값 0
  });
}

// 전역 로그인 상태 (ValueNotifier): null이면 비로그인
final ValueNotifier<UserModel?> currentUser = ValueNotifier(null);
