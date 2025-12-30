import 'package:flutter/material.dart';
import 'screens/map_view.dart';
import 'screens/question_view.dart';
import 'screens/apply_view.dart';
import 'screens/my_page_view.dart';

void main() {
  runApp(const PindaApp());
}

class PindaApp extends StatelessWidget {
  const PindaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Pinda',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blueAccent),
        useMaterial3: true,
        // 시각적 밀도 조정 (데스크탑/웹에서 너무 퍼져 보이는 것 방지)
        visualDensity: VisualDensity.adaptivePlatformDensity,
        fontFamily: 'Pretendard', // pretending to use pretendard
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
  final List<Widget> _pages = const [
    MapView(), // 0: 지도 (홈)
    QuestionView(), // 1: 질문
    ApplyView(), // 2: 응모
    MyPageView(), // 3: 마이페이지
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Row(
          mainAxisSize: MainAxisSize.min, // 중앙 정렬 위해 최소 크기
          children: [
            Icon(Icons.location_on, color: Colors.blueAccent),
            SizedBox(width: 8),
            Text(
              "Pinda",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black, // 앱바 텍스트/아이콘 색상
      ),
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
        selectedItemColor: Colors.blueAccent,
        unselectedItemColor: Colors.grey,
        showUnselectedLabels: true,
        type: BottomNavigationBarType.fixed, // 4개 이상일 때 레이아웃 유지
        onTap: _onItemTapped,
      ),
    );
  }
}
