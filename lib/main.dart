import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'dart:async'; // StreamSubscription
import 'firebase_options.dart';
import 'screens/apply_view.dart';

import 'screens/map_view.dart';
import 'screens/my_page_view.dart';
import 'screens/question_view.dart';
// import 'screens/seoul_region_view.dart'; // Removed

import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // Firestore 추가
import 'models/user_model.dart'; // UserModel Import
import 'state/question_state.dart'; // Question Type

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // 로그인 상태 유지 리스너 등
  FirebaseAuth.instance.authStateChanges().listen((User? user) async {
    if (user != null) {
      // 1. Firestore에서 사용자 정보 가져오기
      try {
        DocumentSnapshot userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get()
            .timeout(const Duration(seconds: 5)); // 5초 타임아웃 추가

        if (userDoc.exists) {
          currentUser.value =
              UserModel.fromMap(userDoc.data() as Map<String, dynamic>);
        } else {
          // 문서가 없는 경우 (예: 기존 가입자) -> 기본값 + 닉네임은 이메일 앞부분
          currentUser.value = UserModel(
            nickname: user.email?.split('@')[0] ?? "익명",
            address: "위치 미설정",
            level: 1,
            tickets: 0,
          );
        }
      } catch (e) {
        print("유저 정보 로드 실패: $e");
        // 에러 시에도 최소한 로그인 상태는 유지
        currentUser.value = UserModel(
          nickname: user.email?.split('@')[0] ?? "익명",
          address: "오류 발생",
          level: 1,
          tickets: 0,
        );
      }
    } else {
      // 로그아웃 됨
      currentUser.value = null;
    }
  });

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '혹시(HOXY)',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.red),
        useMaterial3: true,
        scaffoldBackgroundColor: Colors.grey[50],
        visualDensity: VisualDensity.adaptivePlatformDensity,
        fontFamily: 'Pretendard',
      ),
      home: MainScreen(key: MainScreen.globalKey),
      debugShowCheckedModeBanner: false,
    );
  }
}

class MainScreen extends StatefulWidget {
  static final GlobalKey<MainScreenState> globalKey = GlobalKey();
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => MainScreenState();
}

class MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;

  // 탭별 화면 정의
  // 탭별 화면 정의
  final List<Widget> _pages = [
    const MapView(), // 0: 지도 (기존 MapView 복구)
    const QuestionView(), // 1: 질문
    const ApplyView(), // 2: 응모
    const MyPageView(), // 3: 마이페이지
  ];

  StreamSubscription<User?>? _authSubscription;

  @override
  void initState() {
    super.initState();
    // Auth 상태 변화 감지 등
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }

  // changeTab, _onItemTapped 등 기존 함수 유지...

  void changeTab(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  void navigateToQuestion(Question q) {
    // 상세 지도로 이동 (Push)
    // 질문 위치를 중심으로 하는 상세 지도를 엽니다.
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MapView(
          initialLat: q.latitude,
          initialLng: q.longitude,
          initialZoom: 16, // 상세 줌
          districtName: "질문 상세 위치", // 임시 이름
        ),
      ),
    ).then((_) {
      // 맵이 열린 후 바로 해당 질문의 상세 바텀시트를 띄우는 로직은 MapView 내부에서 처리해야 할 수도 있음.
      // 현재 MapView는 외부에서 openQuestion 호출을 기다림.
      // 하지만 Push된 새 MapView 인스턴스에 접근하려면?
      // -> MapView 생성자에 'initialQuestion'을 넘겨서 initState에서 바로 열게 하는 것이 좋음.
    });

    // NOTE: MapView에 initialQuestion 파라미터가 없으므로,
    // 일단은 위치로만 이동합니다. 사용자가 핀을 보고 누르게 유도하거나,
    // MapView에 initialQuestion 파라미터를 추가해야 완벽함.
    // 이번 변경 범위에서는 "위치로 이동"까지만 구현하거나,
    // 딜레이 후 검색은 불가능(새 페이지라 Key 접근 불가).
    // -> MapView에 `targetQuestionId` 같은걸 넘기는게 좋겠지만,
    // 일단은 위치 이동으로 충분할 수 있음.
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false, // 전체 화면 크기 고정 (키보드 영향 제거)
      appBar: AppBar(
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.location_on, color: Colors.red),
            SizedBox(width: 8),
            Text(
              "혹시(HOXY)",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black,
        actions: [
          // 로그인 시 프로필 아이콘 표시 (StreamBuilder로 즉시 반응)
          StreamBuilder<User?>(
            stream: FirebaseAuth.instance.authStateChanges(),
            builder: (context, snapshot) {
              if (!snapshot.hasData)
                return const SizedBox.shrink(); // 비로그인 시 숨김

              // Auth 로그인 확인됨 -> 아이콘 표시 (프로필 로딩 중엔 회색)
              return ValueListenableBuilder<UserModel?>(
                valueListenable: currentUser,
                builder: (context, user, _) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 16.0),
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedIndex = 3; // 마이페이지로 이동
                        });
                      },
                      child: CircleAvatar(
                        radius: 18,
                        backgroundColor: Colors.red.withOpacity(0.1),
                        child: Icon(
                          Icons.person,
                          size: 24,
                          // 유저 정보 로딩 완료되면 빨간색, 대기 중이면 회색
                          color: user != null ? Colors.red : Colors.grey,
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ],
      ),
      // 현재 선택된 탭의 화면을 보여줌
      body: IndexedStack(
        index: _selectedIndex,
        children: _pages,
      ),
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.map),
            label: '지도',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.chat_bubble_outline),
            label: '질문',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.card_giftcard),
            label: '응모',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'MY',
          ),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.red,
        unselectedItemColor: Colors.grey,
        showUnselectedLabels: true,
        type: BottomNavigationBarType.fixed,
        onTap: _onItemTapped,
      ),
    );
  }
}
