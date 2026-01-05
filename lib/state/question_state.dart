import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class Comment {
  final String id;
  final String content;
  final String author;
  final DateTime createdAt;
  final String? imageBase64; // 이미지(Base64) 추가

  Comment({
    required this.id,
    required this.content,
    required this.author,
    required this.createdAt,
    this.imageBase64,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'content': content,
      'author': author,
      'createdAt': Timestamp.fromDate(createdAt),
      'imageBase64': imageBase64,
    };
  }

  factory Comment.fromMap(Map<String, dynamic> map) {
    return Comment(
      id: map['id'] ?? '',
      content: map['content'] ?? '',
      author: map['author'] ?? 'Unknown',
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      imageBase64: map['imageBase64'],
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

  // 개발용: 데이터 리셋 및 모의 데이터 생성
  // 개발용: 데이터 리셋 및 전국 모의 데이터 생성
  Future<void> resetAndGenerateMockData() async {
    // 1. 기존 데이터 모두 삭제
    final snapshot = await _firestore.collection('questions').get();
    final batch = _firestore.batch();
    for (var doc in snapshot.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();

    // 2. 전국 범위 모의 데이터 생성 (약 100개)
    // 대한민국 대략적 범위: 위도 33.0 ~ 38.5, 경도 126.0 ~ 130.0
    final List<Map<String, dynamic>> templates = [
      {"title": "이 근처 맛집 추천", "content": "점심 먹을만한 곳 추천해주세요!", "category": "맛집"},
      {"title": "조용한 카페", "content": "작업하기 좋은 카페 찾아요.", "category": "카페"},
      {"title": "편의점 위치", "content": "가까운 편의점 어디 있나요?", "category": "편의"},
      {"title": "주차장 질문", "content": "여기 주차 가능한가요?", "category": "주차"},
      {"title": "약국", "content": "늦게까지 하는 약국 찾습니다.", "category": "약국"},
      {"title": "버스 정류장", "content": "강남역 가는 버스 어디서 타요?", "category": "교통"},
      {"title": "놀거리 추천", "content": "심심한데 할거 추천좀요", "category": "놀거리"},
      {"title": "운동할 곳", "content": "일일권 헬스장 있나요?", "category": "운동"},
    ];

    // 생성할 핀 개수 (너무 많으면 느려지므로 200개 정도로 제한)
    const totalPins = 200;
    // 서울/경기 집중도 높이기 위해 범위를 나눌 수도 있지만, 일단 전체 랜덤

    final random = DateTime.now().millisecondsSinceEpoch;
    // 간단한 난수 생성기 (dart:math 없이도 가능하지만 편의상 seed 활용 패턴)
    double getRandom(int seed, double min, double max) {
      final x = (seed * 1664525 + 1013904223) % 4294967296;
      return min + (x / 4294967296) * (max - min);
    }

    // 배치 처리는 500개 제한이 있으므로 안전하게 처리
    // 여기서는 batch 대신 개별 add 혹은 100개씩 batch
    // 질문 생성 loop
    WriteBatch mkBatch = _firestore.batch();
    int batchCount = 0;

    for (var i = 0; i < totalPins; i++) {
      // 난수 생성 (위도: 34.0~38.0, 경도: 126.5~129.5) - 제주도 포함하려면 위도 33.0부터
      final r1 = getRandom(random + i, 33.0, 38.0);
      final r2 = getRandom(random + i * 2, 126.0, 130.0);

      final temp = templates[i % templates.length];

      final q = Question(
        id: 'mock_nation_$i',
        title: temp['title'],
        content: temp['content'],
        category: temp['category'],
        latitude: r1,
        longitude: r2,
        author: '익명${i + 1}',
        createdAt: DateTime.now().subtract(Duration(minutes: i)),
      );

      mkBatch.set(_firestore.collection('questions').doc(q.id), q.toMap());
      batchCount++;

      if (batchCount >= 400) {
        await mkBatch.commit();
        mkBatch = _firestore.batch();
        batchCount = 0;
      }
    }
    if (batchCount > 0) {
      await mkBatch.commit();
    }
  }
}
