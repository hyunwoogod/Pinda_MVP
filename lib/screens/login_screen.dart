import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // Firestore Import
import '../widgets/social_login_buttons.dart';
import 'signup_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _idController = TextEditingController(); // ID Controller (Email 대체)
  final _passwordController = TextEditingController();

  final _idFocusNode = FocusNode();
  final _passwordFocusNode = FocusNode();

  bool _isLoading = false;

  Future<void> _login() async {
    if (_idController.text.isEmpty || _passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("아이디와 비밀번호를 입력해주세요.")),
      );
      return;
    }

    setState(() => _isLoading = true);
    FocusScope.of(context).unfocus(); // 키보드 내리기

    try {
      // 1. ID로 이메일 찾기 (Firestore Query)
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('username', isEqualTo: _idController.text.trim())
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("존재하지 않는 아이디입니다.")),
          );
        }
        return;
      }

      final email = snapshot.docs.first.data()['email'] as String?;
      if (email == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("계정 정보에 오류가 있습니다 (이메일 누락).")),
          );
        }
        return;
      }

      // 2. 이메일 + 비밀번호로 로그인
      UserCredential userCredential =
          await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: _passwordController.text.trim(),
      );

      // 3. 이메일 인증 여부 확인
      if (userCredential.user != null && !userCredential.user!.emailVerified) {
        await FirebaseAuth.instance.signOut(); // 로그아웃
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("이메일 인증이 완료되지 않았습니다.\n메일함을 확인해주세요."),
              duration: Duration(seconds: 3),
            ),
          );
        }
        return;
      }

      if (mounted) Navigator.pop(context); // 성공 시 닫기
    } on FirebaseAuthException catch (e) {
      String message = "로그인 실패: ${e.message}";
      if (e.code == 'wrong-password') message = "비밀번호가 틀렸습니다.";
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("로그인 중 오류가 발생했습니다: $e")),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _goToSignUp() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const SignUpScreen()),
    );
  }

  @override
  void dispose() {
    _idController.dispose();
    _passwordController.dispose();
    _idFocusNode.dispose();
    _passwordFocusNode.dispose();
    super.dispose();
  }

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
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.location_on, size: 80, color: Colors.red),
            const SizedBox(height: 20),
            const Text(
              "핀다(Pinda)",
              style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87),
            ),
            const SizedBox(height: 10),
            const Text(
              "로그인하여 더 많은 기능을 즐기세요",
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
            const SizedBox(height: 40),

            TextField(
              controller: _idController,
              focusNode: _idFocusNode,
              autofocus: true, // 화면 열리면 바로 포커스
              decoration: const InputDecoration(
                labelText: "아이디 (ID)",
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.perm_identity),
              ),
              textInputAction: TextInputAction.next,
              onSubmitted: (_) {
                FocusScope.of(context).requestFocus(_passwordFocusNode);
              },
            ),
            const SizedBox(height: 15),
            TextField(
              controller: _passwordController,
              focusNode: _passwordFocusNode,
              decoration: const InputDecoration(
                labelText: "비밀번호",
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.lock),
              ),
              obscureText: true,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _login(),
              onEditingComplete: () => _login(), // 엔터 키 동작 보장
            ),
            const SizedBox(height: 20),

            if (_isLoading)
              const CircularProgressIndicator()
            else
              Column(
                children: [
                  // 로그인 버튼
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _login,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text("로그인",
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(height: 15),

                  // 아이디로 회원가입 버튼
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: OutlinedButton(
                      onPressed: _goToSignUp,
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text("아이디로 회원가입",
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87)),
                    ),
                  ),
                ],
              ),

            const SizedBox(height: 30),
            const Row(children: [
              Expanded(child: Divider()),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 10),
                child: Text("또는 소셜 로그인", style: TextStyle(color: Colors.grey)),
              ),
              Expanded(child: Divider()),
            ]),
            const SizedBox(height: 20),

            // 소셜 로그인
            const SocialLoginButtons(),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
