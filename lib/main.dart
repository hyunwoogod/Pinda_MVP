import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'firebase_options.dart';
import 'screens/apply_view.dart';

import 'screens/map_view.dart';
import 'screens/my_page_view.dart';
import 'screens/question_view.dart';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // Firestore 추가
import 'models/user_model.dart'; // UserModel Import

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
            .get();

        if (userDoc.exists) {
          Map<String, dynamic> data = userDoc.data() as Map<String, dynamic>;
          currentUser.value = UserModel(
            nickname: data['nickname'] ?? "익명",
            address: data['address'] ?? "알 수 없음",
            level: data['level'] ?? 1,
            tickets: data['tickets'] ?? 0,
          );
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
      title: 'Pinda',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.red),
        useMaterial3: true,
        scaffoldBackgroundColor: Colors.grey[50],
        visualDensity: VisualDensity.adaptivePlatformDensity,
        fontFamily: 'Pretendard',
      ),
      home: const MainScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => MainScreenState();
}

class MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;

  // 탭별 화면 정의
  // (주의: screens 폴더 안에 아래 파일들이 실제로 있어야 합니다)
  final List<Widget> _pages = const [
    MapView(), // 0: 지도 (홈)
    QuestionView(), // 1: 질문
    ApplyView(), // 2: 응모
    MyPageView(), // 3: 마이페이지
  ];

  void changeTab(int index) {
    setState(() {
      _selectedIndex = index;
    });
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
              "핀다(Pinda)",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black,
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
