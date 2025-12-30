import 'package:flutter/foundation.dart';

// --- 데이터 모델 & 상태 관리 ---
class UserModel {
  final String nickname;
  final int level;
  final int tickets;

  UserModel({
    required this.nickname,
    required this.level,
    required this.tickets,
  });
}

// 전역 로그인 상태 (ValueNotifier): null이면 비로그인
final ValueNotifier<UserModel?> currentUser = ValueNotifier(null);
