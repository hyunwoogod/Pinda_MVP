import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nicknameController = TextEditingController();
  final _addressController = TextEditingController();

  bool _isLoading = false;

  Future<void> _register() async {
    if (_emailController.text.isEmpty ||
        _passwordController.text.isEmpty ||
        _nicknameController.text.isEmpty ||
        _addressController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("모든 필드를 입력해주세요.")),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      // 1. Firebase Auth 사용자 생성
      UserCredential userCredential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(
              email: _emailController.text.trim(),
              password: _passwordController.text.trim());

      User? user = userCredential.user;
      if (user != null) {
        // 2. 이메일 인증 메일 발송
        await user.sendEmailVerification();

        // 3. Firestore에 사용자 추가 정보 저장
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'nickname': _nicknameController.text.trim(),
          'address': _addressController.text.trim(),
          'level': 1,
          'tickets': 0,
          'createdAt': FieldValue.serverTimestamp(),
          'email': user.email,
        });

        // 4. 로그아웃 (이메일 인증 후 다시 로그인 유도)
        await FirebaseAuth.instance.signOut();

        if (mounted) {
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) => AlertDialog(
              title: const Text("인증 메일 발송 완료"),
              content: const Text(
                  "입력하신 이메일로 인증 메일을 보냈습니다.\n메일함에서 링크를 클릭하여 인증을 완료한 후 로그인해주세요."),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(context); // Dialog 닫기
                    Navigator.pop(context); // 회원가입 화면 닫기 (로그인 화면으로 복귀)
                  },
                  child: const Text("확인"),
                ),
              ],
            ),
          );
        }
      }
    } on FirebaseAuthException catch (e) {
      String message = "회원가입 실패: ${e.message}";
      if (e.code == 'email-already-in-use') message = "이미 사용 중인 이메일입니다.";
      if (e.code == 'weak-password') message = "비밀번호는 6자리 이상이어야 합니다.";
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("오류가 발생했습니다: $e")),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("회원가입"),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            const Text(
              "핀다와 함께 시작하세요!",
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 30),
            TextField(
              controller: _emailController,
              decoration: const InputDecoration(
                labelText: "이메일 (실제 사용 가능한 메일)",
                hintText: "example@email.com",
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.email),
              ),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 15),
            TextField(
              controller: _passwordController,
              decoration: const InputDecoration(
                labelText: "비밀번호 (6자리 이상)",
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.lock),
              ),
              obscureText: true,
            ),
            const SizedBox(height: 15),
            TextField(
              controller: _nicknameController,
              decoration: const InputDecoration(
                labelText: "닉네임",
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.person),
              ),
            ),
            const SizedBox(height: 15),
            TextField(
              controller: _addressController,
              decoration: const InputDecoration(
                labelText: "우리 동네 (예: 역삼동)",
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.home),
              ),
            ),
            const SizedBox(height: 30),
            if (_isLoading)
              const CircularProgressIndicator()
            else
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _register,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text("가입 및 인증 메일 발송",
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
