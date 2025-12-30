import 'package:flutter/material.dart';
import 'screens/map_view.dart';
import 'screens/question_view.dart';
import 'screens/apply_view.dart';
import 'screens/my_page_view.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const PindaApp());
}

class PindaApp extends StatelessWidget {
  const PindaApp({super.key});

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
