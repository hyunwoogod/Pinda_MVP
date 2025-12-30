import 'package:flutter/material.dart';
import 'dart:async';
import '../models/user_model.dart';
import 'login_screen.dart';

// --- 3. 이벤트 응모 뷰 (Apply View) ---
class ApplyView extends StatefulWidget {
  const ApplyView({super.key});

  @override
  State<ApplyView> createState() => _ApplyViewState();
}

class _ApplyViewState extends State<ApplyView> {
  // 마감 시간: 이번 주 금요일 18:00
  late DateTime _deadline;
  late Timer _timer;
  Duration _timeLeft = Duration.zero;

  @override
  void initState() {
    super.initState();
    _setDeadline();
    _startTimer();
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  void _setDeadline() {
    final now = DateTime.now();
    // 다음 금요일 계산 (금요일=5)
    int daysUntilFriday = DateTime.friday - now.weekday;
    if (daysUntilFriday <= 0) {
      daysUntilFriday += 7; // 이미 지났거나 오늘이면 다음주 금요일로
    }
    final nextFriday = now.add(Duration(days: daysUntilFriday));
    _deadline = DateTime(
      nextFriday.year,
      nextFriday.month,
      nextFriday.day,
      18,
      0,
      0,
    );
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      final now = DateTime.now();
      final difference = _deadline.difference(now);

      if (difference.isNegative) {
        // 마감됨
        setState(() {
          _timeLeft = Duration.zero;
        });
        _timer.cancel();
      } else {
        setState(() {
          _timeLeft = difference;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // 시, 분, 초 계산
    final hours = _timeLeft.inHours;
    final minutes = _timeLeft.inMinutes.remainder(60);
    final seconds = _timeLeft.inSeconds.remainder(60);

    return ValueListenableBuilder<UserModel?>(
      valueListenable: currentUser,
      builder: (context, user, child) {
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.card_giftcard,
                size: 100,
                color: Colors.pinkAccent,
              ),
              const SizedBox(height: 20),
              const Text(
                "이번 주 1등 상품",
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              const Text(
                "🎧 에어팟 프로 2세대",
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.blueAccent,
                ),
              ),
              const SizedBox(height: 40),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 30,
                  vertical: 15,
                ),
                decoration: BoxDecoration(
                  color: Colors.black87,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  "${hours}시간 ${minutes}분 ${seconds}초 남음",
                  style: const TextStyle(
                    fontSize: 24,
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontFamily: "Courier",
                  ),
                ),
              ),
              const SizedBox(height: 60),
              if (user == null)
                Column(
                  children: [
                    const Text("로그인하고 응모하세요!", style: TextStyle(fontSize: 16)),
                    const SizedBox(height: 10),
                    ElevatedButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const LoginScreen(),
                          ),
                        );
                      },
                      child: const Text("로그인하러 가기"),
                    ),
                  ],
                )
              else
                Column(
                  children: [
                    Text(
                      "보유 응모권: ${user.tickets}장",
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.pinkAccent,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 40,
                          vertical: 15,
                        ),
                      ),
                      onPressed: () {
                        if (user.tickets > 0) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text("응모 완료! 당첨을 기원합니다 🙏")),
                          );
                          // (Optional) 차감 로직은 없지만 여기서 처리 가능
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text("응모권이 부족합니다. 미션을 수행하세요!")),
                          );
                        }
                      },
                      child: const Text(
                        "응모하기",
                        style: TextStyle(fontSize: 18, color: Colors.white),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        );
      },
    );
  }
}
