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
  final DateTime createdAt;
  final List<Comment> comments;

  Question({
    required this.id,
    required this.title,
    required this.content,
    required this.category,
    required this.latitude,
    required this.longitude,
    required this.createdAt,
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
      'createdAt': Timestamp.fromDate(createdAt),
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
      createdAt: (map['createdAt'] as Timestamp).toDate(),
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
      final questions = snapshot.docs.map((doc) {
        return Question.fromMap(doc.data(), doc.id);
      }).toList();
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
}
