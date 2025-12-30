import 'package:flutter/material.dart';
import '../models/user_model.dart';

class SocialLoginButtons extends StatelessWidget {
  final VoidCallback? onLoginSuccess;

  const SocialLoginButtons({super.key, this.onLoginSuccess});

  void _performLogin() {
    // 모의 로그인 처리
    currentUser.value = UserModel(
      nickname: "순대감별사",
      level: 3,
      tickets: 5,
    );
    // 콜백이 있으면 실행 (예: 화면 닫기)
    onLoginSuccess?.call();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // 아이디로 회원가입 버튼
        InkWell(
          onTap: _performLogin,
          child: Container(
            width: double.infinity,
            height: 50,
            decoration: BoxDecoration(
              color: Colors.lightBlue,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Center(
              child: Text(
                "아이디로 회원가입",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 15),

        // 카카오 로그인 버튼 (Mock)
        InkWell(
          onTap: _performLogin,
          child: Container(
            width: double.infinity,
            height: 50,
            decoration: BoxDecoration(
              color: const Color(0xFFFEE500),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.chat_bubble, color: Colors.black87, size: 20),
                const SizedBox(width: 10),
                const Text(
                  "카카오로 3초만에 시작하기",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 15),

        // 구글 로그인 버튼 (Mock)
        InkWell(
          onTap: _performLogin,
          child: Container(
            width: double.infinity,
            height: 50,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.g_mobiledata, color: Colors.black87, size: 30),
                const SizedBox(width: 5),
                const Text(
                  "Google로 계속하기",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 15),

        // Apple 로그인 버튼 (Mock)
        InkWell(
          onTap: _performLogin,
          child: Container(
            width: double.infinity,
            height: 50,
            decoration: BoxDecoration(
              color: Colors.black, // Apple Black
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.phone_iphone, color: Colors.white, size: 24),
                SizedBox(width: 5),
                Text(
                  "Apple로 계속하기",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
