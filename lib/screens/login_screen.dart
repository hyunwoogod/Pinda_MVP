import 'package:flutter/material.dart';
import '../widgets/social_login_buttons.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.location_on, size: 80, color: Colors.lightBlue),
            const SizedBox(height: 20),
            const Text(
              "핀다(Pinda)",
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              "지금 여기, 궁금한 곳의 모든 것",
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
            const SizedBox(height: 60),

            // 공통 소셜 로그인 버튼 위젯 (로그인 성공 시 이전 화면으로 복귀)
            SocialLoginButtons(
              onLoginSuccess: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }
}
