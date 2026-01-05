import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';
import '../widgets/social_login_buttons.dart';
import 'login_screen.dart';
import '../widgets/naver_map_web.dart';
import '../state/question_state.dart';
import '../main.dart';

class MyPageView extends StatelessWidget {
  const MyPageView({super.key});

  @override
  Widget build(BuildContext context) {
    // 1. Auth 상태 감지 (StreamBuilder)
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, authSnapshot) {
        // 2. Auth 데이터가 없으면 (비로그인 상태) -> 로그아웃 UI
        if (!authSnapshot.hasData) {
          return SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(height: 50),
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

                  // 이메일 로그인 버튼 (LoginScreen 이동)
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) => const LoginScreen()),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        "이메일로 로그인 / 회원가입",
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  const SizedBox(height: 15),
                  const Row(children: [
                    Expanded(child: Divider()),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 10),
                      child: Text("또는 소셜 로그인",
                          style: TextStyle(color: Colors.grey)),
                    ),
                    Expanded(child: Divider()),
                  ]),
                  const SizedBox(height: 15),

                  // 공통 소셜 로그인 버튼 위젯
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

        // 3. Auth는 있지만 프로필 데이터(User Model) 확인 (ValueListenableBuilder)
        return ValueListenableBuilder<UserModel?>(
          valueListenable: currentUser,
          builder: (context, user, child) {
            // Auth는 있는데 UserModel이 아직 로드되지 않음 -> 로딩 화면
            if (user == null) {
              return const Center(child: CircularProgressIndicator());
            }

            // 4. 로그인 완료 (프로필 표시)
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
                          child:
                              Icon(Icons.person, size: 50, color: Colors.white),
                        ),
                        const SizedBox(width: 20),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    "${user.nickname} 님",
                                    style: const TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.edit,
                                        size: 18, color: Colors.grey),
                                    onPressed: () =>
                                        _showEditProfileDialog(context, user),
                                  ),
                                ],
                              ),
                              Text(
                                "LV.${user.level} ${user.address} 보안관",
                                style: const TextStyle(
                                  color: Colors.red,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 30),

                    // 랭킹 섹션
                    RankingSection(user: user),
                    const SizedBox(height: 30),

                    // 내 질문 목록 섹션
                    _MyQuestionHistory(nickname: user.nickname),
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
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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
                    const SizedBox(height: 40),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(15),
                      decoration: BoxDecoration(
                        color: Colors.red[50],
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Column(
                        children: [
                          const Text("🎟 보유한 응모권",
                              style: TextStyle(fontSize: 16)),
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
                          FirebaseAuth.instance.signOut(); // Firebase 로그아웃
                        },
                        child: const Text("로그아웃"),
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Center(
                        child: Text("문의: ecoguy0818@gmail.com",
                            style:
                                TextStyle(color: Colors.grey, fontSize: 12))),
                    const SizedBox(height: 40),

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

  void _showEditProfileDialog(BuildContext context, UserModel user) {
    // 다이얼로그 내부 상태 관리를 위한 변수들은 StatefulBuilder 안에서 관리하면 좋지만,
    // 초기값 설정 등을 위해 여기서 선언 후 Builder 안에서 참조/업데이트
    final nicknameController = TextEditingController(text: user.nickname);
    final searchController = TextEditingController(); // 검색어 입력

    // 초기값: 현재 사용자의 주소가 있으면 그것을 사용
    String? selectedAddress = user.address.isNotEmpty ? user.address : null;

    showDialog(
      context: context,
      builder: (context) {
        bool isSearching = false;
        List<NaverGeocodingResult> searchResults = [];

        return StatefulBuilder(builder: (context, setState) {
          // 주소 검색 함수
          Future<void> searchAddress() async {
            final query = searchController.text.trim();
            if (query.isEmpty) return;

            // 키보드 내리기
            FocusScope.of(context).unfocus();

            setState(() {
              isSearching = true;
              searchResults.clear();
            });

            try {
              // NaverGeocodingService (Nominatim Wrapper) 호출
              final results = await NaverGeocodingService.geocode(query);
              setState(() {
                searchResults = results;
              });
            } catch (e) {
              print("Error searching address: $e");
            } finally {
              setState(() {
                isSearching = false;
              });
            }
          }

          // 주소 정제 함수 (도/시/군/구/동/읍/면 추출 및 정렬)
          String extractCleanAddress(String fullAddress) {
            // 1. 콤마나 공백으로 분리
            // Nominatim 예: "Yeoksam-dong, Gangnam-gu, Seoul, ..." (역순)
            // 또는 "경기도 성남시 분당구 ..." (정순)
            // 일단 모든 단어를 쪼갬
            final parts = fullAddress.split(RegExp(r'[, ]+'));

            String? doPart;
            String? siPart;
            String? gunPart;
            String? guPart;
            String? dongPart; // 동, 읍, 면, 가

            for (final part in parts) {
              final trimmed = part.trim();
              if (trimmed.isEmpty) continue;

              // 한글 숫자 포함 등이 있을 수 있으므로 단순화해서 체크
              // 주소 끝자리 기준 분류
              if (trimmed.endsWith('도')) {
                doPart = trimmed;
              } else if (trimmed.endsWith('시')) {
                siPart = trimmed;
              } else if (trimmed.endsWith('군')) {
                gunPart = trimmed;
              } else if (trimmed.endsWith('구')) {
                guPart = trimmed;
              } else if (trimmed.endsWith('동') ||
                  trimmed.endsWith('읍') ||
                  trimmed.endsWith('면') ||
                  trimmed.endsWith('가')) {
                // 동이 여러개일 경우 (예: 역삼1동) 가장 마지막 것 또는 구체적인 것 사용?
                // 보통 Nominatim은 '역삼동' 하나만 주거나 함.
                // 이미 찾았으면 덮어쓰기? (보통 앞쪽에 구체적인게 나옴 vs 뒤쪽에 나옴)
                // Nominatim 역순(상세->광역)일 경우: "Yeoksam-dong, ..." -> 첫번째가 동.
                // 리스트 순회 순서에 따라 다름.
                // 여기서는 '가장 상세한 주소' 하나만 잡으면 됨.
                // 만약 "역삼1동"과 "역삼동"이 같이 있다면?
                // 일단 먼저 발견된 것을 우선하되, 루프 돌면서 갱신?
                // Nominatim raw string 순서에 의존하기보다, 그냥 발견되면 저장.
                // 단, '동'이 여러번 나오면? -> 보통 주소에 동이 두번 들어가지 않음 (법정동, 행정동 겹칠때 제외)
                if (dongPart == null) dongPart = trimmed;
              }
            }

            // 조합 (위계 순서: 도 > 시 > 군 > 구 > 동)
            final buffer = StringBuffer();
            if (doPart != null) buffer.write('$doPart ');
            if (siPart != null) buffer.write('$siPart ');
            if (gunPart != null) buffer.write('$gunPart ');
            if (guPart != null) buffer.write('$guPart ');
            if (dongPart != null) buffer.write('$dongPart');

            final result = buffer.toString().trim();

            // 만약 추출된게 하나도 없으면 (외국 주소 등) 원본의 앞부분 반환
            return result.isNotEmpty
                ? result
                : (parts.isNotEmpty ? parts.first : fullAddress);
          }

          return AlertDialog(
            title: const Text("프로필 수정"),
            content: SizedBox(
              width: double.maxFinite,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nicknameController,
                    decoration: const InputDecoration(labelText: "닉네임"),
                  ),
                  const SizedBox(height: 20),

                  // 주소 검색 영역
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: searchController,
                          decoration: const InputDecoration(
                            labelText: "동네 검색 (예: 제주도)",
                            hintText: "동/읍/면 이름을 입력하세요",
                            isDense: true,
                          ),
                          onSubmitted: (_) => searchAddress(),
                        ),
                      ),
                      IconButton(
                        icon: isSearching
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.search),
                        onPressed: isSearching ? null : searchAddress,
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // 선택된 주소 표시
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(8),
                    color: Colors.grey[100],
                    child: Text(
                      "선택된 위치: ${selectedAddress ?? '없음'}",
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),

                  // 검색 결과 리스트 (결과가 있을 때만 표시)
                  if (searchResults.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    const Divider(),
                    const Text("검색 결과 (클릭하여 선택)",
                        style: TextStyle(fontSize: 12, color: Colors.grey)),
                    Flexible(
                      child: SizedBox(
                        height: 150, // 높이 제한
                        child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: searchResults.length,
                          itemBuilder: (context, index) {
                            final item = searchResults[index];
                            return ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: const Icon(Icons.location_on,
                                  size: 16, color: Colors.grey),
                              title: Text(item.address,
                                  style: const TextStyle(fontSize: 13),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis),
                              onTap: () {
                                final extracted =
                                    extractCleanAddress(item.address);
                                setState(() {
                                  selectedAddress = extracted;
                                  // 검색 결과는 숨기거나 유지 (여기선 유지하되 선택값 업데이트)
                                  // searchResults.clear(); // 원하면 닫기 가능
                                });
                              },
                            );
                          },
                        ),
                      ),
                    ),
                  ] else if (isSearching) ...[
                    const Padding(
                      padding: EdgeInsets.all(8.0),
                      child:
                          Text("검색 중...", style: TextStyle(color: Colors.grey)),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("취소")),
              ElevatedButton(
                onPressed: () async {
                  final newNickname = nicknameController.text.trim();
                  final newAddress = selectedAddress;

                  if (newNickname.isNotEmpty &&
                      newAddress != null &&
                      newAddress.isNotEmpty) {
                    final uid = FirebaseAuth.instance.currentUser?.uid;
                    if (uid != null) {
                      await FirebaseFirestore.instance
                          .collection('users')
                          .doc(uid)
                          .update({
                        'nickname': newNickname,
                        'address': newAddress,
                      });
                      // 로컬 상태 강제 업데이트
                      currentUser.value = UserModel(
                        nickname: newNickname,
                        address: newAddress,
                        level: user.level,
                        tickets: user.tickets,
                        acceptedCount: user.acceptedCount,
                      );
                    }
                    if (context.mounted) Navigator.pop(context);
                  } else {
                    // 입력 미완료 시 알림 (선택사항)
                    ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("닉네임과 주소를 모두 설정해주세요.")));
                  }
                },
                child: const Text("저장"),
              ),
            ],
          );
        });
      },
    );
  }
}

class RankingSection extends StatelessWidget {
  final UserModel user;
  const RankingSection({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "🏆 ${user.address} 명예의 전당",
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[200]!),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.1),
                blurRadius: 5,
                spreadRadius: 2,
              )
            ],
          ),
          child: Column(
            children: [
              // 1~10위 Mock Data 표시
              ...List.generate(10, (index) {
                final rank = index + 1;
                final nickname = "우리동네보안관$rank"; // 가상 닉네임
                final count = 100 - (rank * 5); // 가상 횟수
                return ListTile(
                  leading: _buildRankIcon(rank),
                  title: Text(nickname),
                  trailing: Text(
                    "$count회 해결",
                    style: const TextStyle(
                        color: Colors.red, fontWeight: FontWeight.bold),
                  ),
                  tileColor: null,
                );
              }),
              const Divider(),

              // 내 순위 표시 (Mock: 실제 내 acceptedCount가 0이면 순위 밖, 아니면 임의의 순위 표시)
              if (user.acceptedCount == 0)
                ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Colors.grey,
                    child: Text("-", style: TextStyle(color: Colors.white)),
                  ),
                  title: const Text("나의 순위"),
                  trailing: const Text("순위 밖 (0회)",
                      style: TextStyle(color: Colors.grey)),
                  tileColor: Colors.red[50], // 내 순위 강조
                )
              else
                ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Colors.grey,
                    child: Text("-", style: TextStyle(color: Colors.white)),
                  ),
                  title: const Text("나의 순위"),
                  trailing: Text(
                      "${10 + (user.level * 2)}위 (예상)"), // 랭킹 시스템 연동 전 임의 표시
                  tileColor: Colors.red[50],
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRankIcon(int rank) {
    Color color;
    if (rank == 1) {
      color = Colors.amber;
    } else if (rank == 2) {
      color = Colors.grey;
    } else if (rank == 3) {
      color = Colors.brown;
    } else {
      return Text("$rank",
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold));
    }

    return Icon(Icons.emoji_events, color: color);
  }

  // 임의의 랭킹 데이터 생성 (테스트용)
  Future<void> _generateMockData(String address) async {
    final firestore = FirebaseFirestore.instance;
    final batch = firestore.batch();

    // 기존 더미 데이터 삭제 로직 (선택사항)이 없으므로 추가만 함.
    // 1등부터 10등까지 생성
    for (int i = 1; i <= 10; i++) {
      final docRef = firestore.collection('users').doc('mock_user_$i');
      batch.set(docRef, {
        'nickname': '우리동네보안관$i',
        'address': address,
        'acceptedCount': 100 - (i * 5), // 95, 90, 85 ...
        'level': 5,
        'tickets': 0,
      });
    }
    await batch.commit();
  }
}

class _MyQuestionHistory extends StatelessWidget {
  final String nickname;

  const _MyQuestionHistory({required this.nickname});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<List<Question>>(
      valueListenable: QuestionState(),
      builder: (context, questions, child) {
        // 내 닉네임과 작성자가 일치하는 질문 필터링
        final myQuestions =
            questions.where((q) => q.author == nickname).toList();

        if (myQuestions.isEmpty) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "📜 내 질문 히스토리",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Center(
                  child: Text("아직 작성한 질문이 없습니다.",
                      style: TextStyle(color: Colors.grey)),
                ),
              ),
            ],
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "📜 내 질문 히스토리",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                Text(
                  "${myQuestions.length}건",
                  style: const TextStyle(
                      color: Colors.red, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ListView.separated(
              physics: const NeverScrollableScrollPhysics(), // 부모 스크롤 사용
              shrinkWrap: true,
              itemCount: myQuestions.length,
              separatorBuilder: (context, index) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final q = myQuestions[index];
                final isAnswered = q.comments.isNotEmpty;
                final dateStr =
                    "${q.createdAt.month}월 ${q.createdAt.day}일 ${q.createdAt.hour}:${q.createdAt.minute.toString().padLeft(2, '0')}";

                return Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey[200]!),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.1),
                        blurRadius: 3,
                        spreadRadius: 1,
                      )
                    ],
                  ),
                  child: ListTile(
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    title: Text(
                      q.title.isNotEmpty ? q.title : q.content,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 4),
                        Text(
                          "$dateStr • ${q.category}",
                          style:
                              const TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: isAnswered ? Colors.green[50] : Colors.grey[100],
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isAnswered ? Colors.green : Colors.grey,
                        ),
                      ),
                      child: Text(
                        isAnswered ? "답변 완료" : "답변 대기",
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: isAnswered ? Colors.green : Colors.grey,
                        ),
                      ),
                    ),
                    onTap: () {
                      MainScreen.globalKey.currentState?.navigateToQuestion(q);
                    },
                  ),
                );
              },
            ),
          ],
        );
      },
    );
  }
}
