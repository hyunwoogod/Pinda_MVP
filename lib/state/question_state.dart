import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class Comment {
  final String id;
  final String content;
  final String author;
  final DateTime createdAt;

  Comment({
    required this.id,
    required this.content,
    required this.author,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'content': content,
      'author': author,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  factory Comment.fromMap(Map<String, dynamic> map) {
    return Comment(
      id: map['id'] ?? '',
      content: map['content'] ?? '',
      author: map['author'] ?? 'Unknown',
      createdAt: (map['createdAt'] as Timestamp).toDate(),
    );
  }
}

class Question {
  final String id;
  final String title;
  final String content;
  final String category;
  final double latitude;
  final double longitude;
  final String author; // 작성자 추가
  final DateTime createdAt;
  final DateTime? resolvedAt; // 해결된 시간 (5분 후 삭제 로직용)
  final List<Comment> comments;

  Question({
    required this.id,
    required this.title,
    required this.content,
    required this.category,
    required this.latitude,
    required this.longitude,
    required this.author,
    required this.createdAt,
    this.resolvedAt,
    this.comments = const [],
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'content': content,
      'category': category,
      'latitude': latitude,
      'longitude': longitude,
      'author': author,
      'createdAt': Timestamp.fromDate(createdAt),
      'resolvedAt': resolvedAt != null ? Timestamp.fromDate(resolvedAt!) : null,
      'comments': comments.map((c) => c.toMap()).toList(),
    };
  }

  factory Question.fromMap(Map<String, dynamic> map, String docId) {
    return Question(
      id: docId,
      title: map['title'] ?? '',
      content: map['content'] ?? '',
      category: map['category'] ?? '',
      latitude: (map['latitude'] as num).toDouble(),
      longitude: (map['longitude'] as num).toDouble(),
      author: map['author'] ?? '익명', // 없을 경우 호환성 유지
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      resolvedAt: map['resolvedAt'] != null
          ? (map['resolvedAt'] as Timestamp).toDate()
          : null,
      comments: (map['comments'] as List<dynamic>?)
              ?.map((c) => Comment.fromMap(c as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}

class QuestionState extends ValueNotifier<List<Question>> {
  static final QuestionState _instance = QuestionState._internal();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  factory QuestionState() => _instance;

  QuestionState._internal() : super([]) {
    _initRealtimeUpdates();
  }

  void _initRealtimeUpdates() {
    // Firestore 컬렉션 실시간 구독
    _firestore
        .collection('questions')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .listen((snapshot) {
      final now = DateTime.now();
      final questions = <Question>[];

      for (var doc in snapshot.docs) {
        final q = Question.fromMap(doc.data(), doc.id);

        // 1. 해결된 질문 5분 후 삭제 로직
        if (q.resolvedAt != null) {
          final diff = now.difference(q.resolvedAt!);
          if (diff.inMinutes >= 5) {
            deleteQuestion(q.id); // 비동기 삭제
            continue; // UI 리스트에는 포함하지 않음
          }
        }

        // 2. 답변 없는 질문 30분 후 삭제 로직
        if (q.comments.isEmpty) {
          final diff = now.difference(q.createdAt);
          if (diff.inMinutes >= 30) {
            deleteQuestion(q.id);
            continue;
          }
        }

        questions.add(q);
      }
      value = questions; // UI 자동 업데이트
    });
  }

  Future<void> addQuestion(Question question) async {
    // Firestore에 저장 (ID는 문서 ID로 자동 지정되거나, 지정한 ID 사용)
    await _firestore
        .collection('questions')
        .doc(question.id)
        .set(question.toMap());
  }

  Future<void> addComment(String questionId, Comment comment) async {
    // 댓글 추가 (ArrayUnion 사용)
    await _firestore.collection('questions').doc(questionId).update({
      'comments': FieldValue.arrayUnion([comment.toMap()])
    });
  }

  Future<void> deleteQuestion(String questionId) async {
    // 질문 삭제
    await _firestore.collection('questions').doc(questionId).delete();
  }

  Future<void> resolveQuestion(String questionId, String answerAuthor) async {
    // 트랜잭션 사용: 답변 작성자 점수 증가 + 질문 해결 상태 업데이트
    try {
      await _firestore.runTransaction((transaction) async {
        // 1. 답변 작성자의 유저 문서 찾기 (닉네임 기반)
        // **주의**: 닉네임이 고유해야 정확함. ID기반이 더 안전하지만 현재 구조상 닉네임 사용
        final userQuery = await _firestore
            .collection('users')
            .where('nickname', isEqualTo: answerAuthor)
            .limit(1)
            .get();

        if (userQuery.docs.isNotEmpty) {
          final userDoc = userQuery.docs.first;
          final currentScore = userDoc.data()['acceptedCount'] ?? 0;
          transaction.update(userDoc.reference, {
            'acceptedCount': currentScore + 1,
          });
        }

        // 2. 질문에 해결 시간(resolvedAt) 기록
        final questionRef = _firestore.collection('questions').doc(questionId);
        transaction.update(questionRef, {
          'resolvedAt': FieldValue.serverTimestamp(),
        });
      });
    } catch (e) {
      debugPrint("Resolve Error: $e");
      rethrow;
    }
  }
}
