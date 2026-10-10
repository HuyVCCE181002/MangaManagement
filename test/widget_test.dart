import 'package:flutter_test/flutter_test.dart';
import 'package:manga_management_app/core/utils/validators.dart';
import 'package:manga_management_app/features/manga/data/models/manga_model.dart';
import 'package:manga_management_app/features/manga/domain/entities/manga.dart';

void main() {
  group('Validators Unit Tests', () {
    test('required validator should return error when value is empty or null', () {
      expect(Validators.required(null, 'Tên'), 'Tên không được để trống');
      expect(Validators.required('', 'Tên'), 'Tên không được để trống');
      expect(Validators.required('   ', 'Tên'), 'Tên không được để trống');
      expect(Validators.required('One Piece', 'Tên'), isNull);
    });

    test('positiveNumber validator should validate non-negative integers', () {
      expect(Validators.positiveNumber('abc', 'Số tập'), 'Số tập phải là số nguyên không âm');
      expect(Validators.positiveNumber('-5', 'Số tập'), 'Số tập phải là số nguyên không âm');
      expect(Validators.positiveNumber('100', 'Số tập'), isNull);
      expect(Validators.positiveNumber('0', 'Số tập'), isNull);
    });

    test('rating validator should validate range 0.0 to 10.0', () {
      expect(Validators.rating('11'), 'Điểm đánh giá phải từ 0.0 đến 10.0');
      expect(Validators.rating('-1'), 'Điểm đánh giá phải từ 0.0 đến 10.0');
      expect(Validators.rating('9.5'), isNull);
      expect(Validators.rating('0.0'), isNull);
    });
  });

  group('Manga Entity & Model Tests', () {
    test('readingProgressPercentage should calculate correct ratio', () {
      final manga = Manga(
        id: 'test-1',
        title: 'Solo Leveling',
        author: 'Chugong',
        description: 'Test',
        coverUrl: 'https://example.com/cover.jpg',
        genres: ['Action'],
        status: 'Ongoing',
        totalChapters: 200,
        currentChapter: 100,
        rating: 9.5,
        releaseYear: 2018,
        updatedAt: DateTime.now(),
      );

      expect(manga.readingProgressPercentage, 0.5);
      expect(manga.isCompleted, isFalse);
    });

    test('MangaModel fromJson and toJson should serialize and deserialize accurately', () {
      final now = DateTime.now();
      final json = {
        'id': 'manga-99',
        'title': 'Jujutsu Kaisen',
        'originalTitle': '呪術廻戦',
        'author': 'Gege Akutami',
        'artist': 'Gege Akutami',
        'description': 'Chú thuật hồi chiến',
        'coverUrl': 'https://example.com/jjk.jpg',
        'genres': ['Action', 'Supernatural'],
        'status': 'Completed',
        'totalChapters': 271,
        'currentChapter': 271,
        'rating': 9.2,
        'releaseYear': 2018,
        'updatedAt': now.toIso8601String(),
      };

      final model = MangaModel.fromJson(json);
      expect(model.id, 'manga-99');
      expect(model.title, 'Jujutsu Kaisen');
      expect(model.status, 'Completed');
      expect(model.totalChapters, 271);

      final entity = model.toEntity();
      expect(entity.isCompleted, isTrue);
      expect(entity.readingProgressPercentage, 1.0);

      final reEncodedJson = model.toJson();
      expect(reEncodedJson['id'], 'manga-99');
      expect(reEncodedJson['title'], 'Jujutsu Kaisen');
    });
  });
}
