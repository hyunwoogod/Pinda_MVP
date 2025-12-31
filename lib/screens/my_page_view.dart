import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../widgets/social_login_buttons.dart';

class MyPageView extends StatelessWidget {
  const MyPageView({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<UserModel?>(
      valueListenable: currentUser,
      builder: (context, user, child) {
        if (user == null) {
          // 비로그인 상태 UI (Embedded Login)
          return SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(height: 50), // 상단 여백 추가
                  const Icon(
                    Icons.location_on, // Pinda PIN
                    size: 80,
                    color: Colors.red,
                  ),
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
                    "지금 거기, 궁금한 곳의 모든 것",
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                  const SizedBox(height: 60),

                  // 공통 소셜 로그인 버튼 위젯 (로그인 성공 시 화면 유지 -> 즉시 프로필 전환됨)
                  const SocialLoginButtons(),

                  const SizedBox(height: 40),
                  const Text("문의: ecoguy0818@gmail.com",
                      style: TextStyle(color: Colors.grey, fontSize: 12)),
                  const SizedBox(height: 50),
                ],
              ),
            ),
          );
        }

        // 로그인 상태 UI
        return SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 40),
                Row(
                  children: [
                    const CircleAvatar(
                      radius: 40,
                      backgroundColor: Colors.red,
                      child: Icon(Icons.person, size: 50, color: Colors.white),
                    ),
                    const SizedBox(width: 20),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "${user.nickname} 님",
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          "LV.${user.level} 동네 보안관",
                          style: const TextStyle(
                            color: Colors.red,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 30),
                const Text(
                  "나의 경험치 (다음 레벨까지 30%)",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                const LinearProgressIndicator(
                  value: 0.7,
                  backgroundColor: Colors.grey,
                  color: Colors.red,
                  minHeight: 10,
                ),
                const SizedBox(height: 30),
                const Text(
                  "🏆 획득한 배지",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 15),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildBadge(Icons.star, "첫 답변", Colors.yellow),
                    _buildBadge(
                      Icons.local_fire_department,
                      "핫플 마스터",
                      Colors.red,
                    ),
                    _buildBadge(Icons.verified, "신뢰도 100%", Colors.green),
                  ],
                ),
                const SizedBox(height: 40), // Spacer 대신 SizedBox
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(15),
                  decoration: BoxDecoration(
                    color: Colors.red[50],
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    children: [
                      const Text("🎟 보유한 응모권", style: TextStyle(fontSize: 16)),
                      Text(
                        "${user.tickets}장",
                        style: const TextStyle(
                          fontSize: 30,
                          fontWeight: FontWeight.bold,
                          color: Colors.red,
                        ),
                      ),
                      const Text(
                        "이번 주 1등 상품: 에어팟 프로 2",
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                // 로그아웃 버튼
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () {
                      currentUser.value = null; // 로그아웃
                    },
                    child: const Text("로그아웃"),
                  ),
                ),
                const SizedBox(height: 20),
                const Center(
                    child: Text("문의: ecoguy0818@gmail.com",
                        style: TextStyle(color: Colors.grey, fontSize: 12))),
                const SizedBox(height: 20),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildBadge(IconData icon, String label, Color color) {
    return Column(
      children: [
        CircleAvatar(
          radius: 30,
          backgroundColor: color.withOpacity(0.2),
          child: Icon(icon, color: color, size: 30),
        ),
        const SizedBox(height: 5),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }
}
