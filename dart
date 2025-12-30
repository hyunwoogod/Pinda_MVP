import 'package:flutter/material.dart';
import 'dart:async'; // AI 처리 시간 시뮬레이션용

void main() {
  runApp(const NowHereApp());
}

class NowHereApp extends StatelessWidget {
  const NowHereApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'NowHere',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: const MainScreen(),
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;

  // 화면 3개: 지도(Map), 촬영(Camera), 마이페이지(MyPage)
  static final List<Widget> _widgetOptions = <Widget>[
    const MapView(),    // 1. 지도 뷰
    const CameraView(), // 2. AI 카메라 뷰
    const MyPageView(), // 3. 마이페이지
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
        title: const Text('NowHere (나우히어)', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: _widgetOptions.elementAt(_selectedIndex),
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(icon: Icon(Icons.map), label: '지도'),
          BottomNavigationBarItem(icon: Icon(Icons.camera_alt), label: '촬영'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: '내 정보'),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.blue,
        onTap: _onItemTapped,
      ),
    );
  }
}

// --- 1. 지도 뷰 (Map View) ---
class MapView extends StatelessWidget {
  const MapView({super.key});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // 실제 지도 API 대신 배경색으로 대체 (Google Maps가 들어갈 자리)
        Container(color: Colors.grey[200]),
        const Center(child: Text("지도 영역 (Google Maps API)", style: TextStyle(color: Colors.grey))),
        
        // 핀 1: 외대 정문 순대차
        _buildPin(context, 100, 150, "외대 정문", "순대차 왔나요?", Colors.red),
        // 핀 2: 편의점 두바이 초콜릿
        _buildPin(context, 250, 300, "GS25 이문점", "두바이 초콜릿 재고 있나요?", Colors.orange),
        // 핀 3: 도서관 자리
        _buildPin(context, 80, 400, "중앙도서관", "3열람실 자리 있나요?", Colors.blue),
      ],
    );
  }

  Widget _buildPin(BuildContext context, double top, double left, String title, String question, Color color) {
    return Positioned(
      top: top,
      left: left,
      child: GestureDetector(
        onTap: () {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: Text(title),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Q. $question", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  const Text("💰 보상: 에어팟 응모권 1장"),
                  const SizedBox(height: 5),
                  const Text("📸 미션: 현재 상황 사진 찍기"),
                ],
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text("닫기")),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("촬영 탭으로 이동합니다!")));
                  }, 
                  child: const Text("답변하기")
                ),
              ],
            ),
          );
        },
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), boxShadow: [const BoxShadow(blurRadius: 3, color: Colors.black26)]),
              child: Text(question, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
            ),
            Icon(Icons.location_on, size: 40, color: color),
          ],
        ),
      ),
    );
  }
}

// --- 2. 촬영 뷰 (Camera View + AI Logic) ---
class CameraView extends StatefulWidget {
  const CameraView({super.key});

  @override
  State<CameraView> createState() => _CameraViewState();
}

class _CameraViewState extends State<CameraView> {
  bool _isProcessing = false;
  bool _isUploaded = false;

  void _takePhoto() {
    setState(() { _isProcessing = true; });

    // AI 블러 처리 시뮬레이션 (2초 대기)
    Timer(const Duration(seconds: 2), () {
      setState(() {
        _isProcessing = false;
        _isUploaded = true;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: _isUploaded
          ? Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.check_circle, color: Colors.green, size: 80),
                const SizedBox(height: 20),
                const Text("전송 완료!", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                const Text("AI가 얼굴을 자동으로 가렸습니다.", style: TextStyle(color: Colors.grey)),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () => setState(() { _isUploaded = false; }),
                  child: const Text("다른 미션 수행하기"),
                )
              ],
            )
          : Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 300,
                  height: 300,
                  color: Colors.black12,
                  child: _isProcessing
                      ? const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            CircularProgressIndicator(),
                            SizedBox(height: 20),
                            Text("AI가 얼굴을 블러 처리 중입니다...", style: TextStyle(fontWeight: FontWeight.bold)),
                          ],
                        )
                      : const Icon(Icons.camera_alt, size: 100, color: Colors.grey),
                ),
                const SizedBox(height: 30),
                ElevatedButton.icon(
                  onPressed: _isProcessing ? null : _takePhoto,
                  icon: const Icon(Icons.camera),
                  label: const Text("실시간 촬영하기 (갤러리 불가)"),
                  style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15)),
                ),
              ],
            ),
    );
  }
}

// --- 3. 마이페이지 (My Page + Gamification) ---
class MyPageView extends StatelessWidget {
  const MyPageView({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              CircleAvatar(radius: 40, backgroundColor: Colors.blueAccent, child: Icon(Icons.person, size: 50, color: Colors.white)),
              SizedBox(width: 20),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("순대감별사 님", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                  Text("LV.3 동네 보안관", style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold)),
                ],
              )
            ],
          ),
          const SizedBox(height: 30),
          const Text("나의 경험치 (다음 레벨까지 30%)", style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          const LinearProgressIndicator(value: 0.7, backgroundColor: Colors.grey, color: Colors.blue, minHeight: 10),
          const SizedBox(height: 30),
          const Text("🏆 획득한 배지", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 15),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildBadge(Icons.star, "첫 답변", Colors.yellow),
              _buildBadge(Icons.local_fire_department, "핫플 마스터", Colors.red),
              _buildBadge(Icons.verified, "신뢰도 100%", Colors.green),
            ],
          ),
          const Spacer(),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(color: Colors.blue[50], borderRadius: BorderRadius.circular(10)),
            child: const Column(
              children: [
                Text("🎟 보유한 응모권", style: TextStyle(fontSize: 16)),
                Text("5장", style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold, color: Colors.blue)),
                Text("이번 주 1등 상품: 에어팟 프로 2", style: TextStyle(fontSize: 12, color: Colors.grey)),
              ],
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildBadge(IconData icon, String label, Color color) {
    return Column(
      children: [
        CircleAvatar(radius: 30, backgroundColor: color.withOpacity(0.2), child: Icon(icon, color: color, size: 30)),
        const SizedBox(height: 5),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }
}