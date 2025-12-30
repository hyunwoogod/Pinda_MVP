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
}

class QuestionState extends ValueNotifier<List<Question>> {
  static final QuestionState _instance = QuestionState._internal();

  factory QuestionState() => _instance;

  QuestionState._internal()
      : super([
          Question(
            id: "gs25_imun",
            title: "GS25 이문점",
            content: "두바이 초콜릿 재고 있나요?",
            category: "재고/상품",
            latitude: 37.5966,
            longitude: 127.0601,
            createdAt: DateTime.now().subtract(const Duration(minutes: 15)),
            comments: [
              Comment(
                  id: "c1",
                  content: "아까 갔을 땐 없었어요 ㅠㅠ",
                  author: "익명1",
                  createdAt:
                      DateTime.now().subtract(const Duration(minutes: 5))),
            ],
          ),
          Question(
            id: "library_main",
            title: "중앙도서관",
            content: "3열람실 자리 있나요?",
            category: "시설/주차",
            latitude: 37.5955,
            longitude: 127.0528,
            createdAt: DateTime.now().subtract(const Duration(minutes: 60)),
            comments: [],
          ),
        ]);

  void addQuestion(Question question) {
    value = [...value, question];
  }

  void addComment(String questionId, Comment comment) {
    value = value.map((q) {
      if (q.id == questionId) {
        return Question(
          id: q.id,
          title: q.title,
          content: q.content,
          category: q.category,
          latitude: q.latitude,
          longitude: q.longitude,
          createdAt: q.createdAt,
          comments: [...q.comments, comment],
        );
      }
      return q;
    }).toList();
  }
}
