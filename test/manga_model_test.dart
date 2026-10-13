import 'package:flutter_test/flutter_test.dart';
import 'package:manga_management_app/models/manga.dart';

void main() {
  group('Manga Model - Tests', () {
    final sampleMap = {
      'id': 'm1',
      'title': 'Naruto',
      'author': 'Masashi Kishimoto',
      'description': 'Câu chuyện về ninja trẻ tìm kiếm sự công nhận.',
      'cover_url': 'https://example.com/naruto.jpg',
      'genre': 'Action',
      'status': 'Completed',
      'total_chapters': 700,
      'current_chapter': 350,
      'rating': 9.0,
      'is_favorite': 1,
    };

    test('fromMap() ánh xạ đúng tất cả trường từ SQLite Map', () {
      final m = Manga.fromMap(sampleMap);

      expect(m.id, 'm1');
      expect(m.title, 'Naruto');
      expect(m.author, 'Masashi Kishimoto');
      expect(m.description, 'Câu chuyện về ninja trẻ tìm kiếm sự công nhận.');
      expect(m.coverUrl, 'https://example.com/naruto.jpg');
      expect(m.genre, 'Action');
      expect(m.status, 'Completed');
      expect(m.totalChapters, 700);
      expect(m.currentChapter, 350);
      expect(m.rating, 9.0);
      expect(m.isFavorite, isTrue);
    });

    test('fromMap() chấp nhận cả snake_case và camelCase keys', () {
      final camelMap = {
        'id': 'm2',
        'title': 'Bleach',
        'author': 'Tite Kubo',
        'coverUrl': 'https://example.com/bleach.jpg',
        'genre': 'Action',
        'status': 'Completed',
        'totalChapters': 686,
        'currentChapter': 100,
        'rating': 8.5,
        'isFavorite': 0,
      };

      final m = Manga.fromMap(camelMap);
      expect(m.coverUrl, 'https://example.com/bleach.jpg');
      expect(m.totalChapters, 686);
      expect(m.isFavorite, isFalse);
    });

    test('fromMap() sử dụng giá trị mặc định khi thiếu trường', () {
      final minimalMap = {
        'id': 'm3',
        'title': 'Test',
        'author': 'Author',
        'cover_url': 'url',
      };

      final m = Manga.fromMap(minimalMap);
      expect(m.description, '');
      expect(m.genre, 'Action');
      expect(m.status, 'Ongoing');
      expect(m.totalChapters, 0);
      expect(m.currentChapter, 0);
      expect(m.rating, 8.0);
      expect(m.isFavorite, isFalse);
    });

    test('toMap() lưu đúng dạng snake_case cho SQLite', () {
      final m = Manga(
        id: 'm4',
        title: 'One Piece',
        author: 'Oda',
        description: 'Tìm kho báu One Piece',
        coverUrl: 'https://example.com/op.jpg',
        genre: 'Adventure',
        status: 'Ongoing',
        totalChapters: 1000,
        currentChapter: 50,
        rating: 9.5,
        isFavorite: true,
      );

      final map = m.toMap();
      expect(map['id'], 'm4');
      expect(map['title'], 'One Piece');
      expect(map['cover_url'], 'https://example.com/op.jpg');
      expect(map['total_chapters'], 1000);
      expect(map['current_chapter'], 50);
      expect(map['is_favorite'], 1);
    });

    test('toJson() và fromJson() làm việc đúng với camelCase', () {
      final original = Manga(
        id: 'm5',
        title: 'Spy x Family',
        author: 'Tatsuya Endo',
        description: 'Điệp viên lập gia đình giả',
        coverUrl: 'https://example.com/spy.jpg',
        genre: 'Comedy',
        status: 'Ongoing',
        totalChapters: 100,
        currentChapter: 25,
        rating: 9.3,
        isFavorite: false,
      );

      final json = original.toJson();
      final restored = Manga.fromJson(json);

      expect(restored.id, original.id);
      expect(restored.title, original.title);
      expect(restored.coverUrl, original.coverUrl);
      expect(restored.isFavorite, original.isFavorite);
    });

    test('progressPercentage tính đúng tỉ lệ phần trăm', () {
      final m = Manga(
        id: '1',
        title: 't',
        author: 'a',
        description: '',
        coverUrl: 'u',
        genre: 'g',
        status: 's',
        totalChapters: 100,
        currentChapter: 25,
        rating: 8.0,
      );

      expect(m.progressPercentage, 0.25);
    });

    test('progressPercentage clamp trong khoảng 0.0 - 1.0', () {
      final m1 = Manga(
        id: '1',
        title: 't',
        author: 'a',
        description: '',
        coverUrl: 'u',
        genre: 'g',
        status: 's',
        totalChapters: 100,
        currentChapter: 150, // Vượt quá
        rating: 8.0,
      );
      expect(m1.progressPercentage, 1.0);

      final m2 = Manga(
        id: '2',
        title: 't',
        author: 'a',
        description: '',
        coverUrl: 'u',
        genre: 'g',
        status: 's',
        totalChapters: 0,
        currentChapter: 10,
        rating: 8.0,
      );
      expect(m2.progressPercentage, 0.0);
    });

    test('copyWith() chỉ thay đổi các trường được chỉ định', () {
      final m = Manga(
        id: '1',
        title: 'Original',
        author: 'A',
        description: 'desc',
        coverUrl: 'url',
        genre: 'Action',
        status: 'Ongoing',
        totalChapters: 100,
        currentChapter: 10,
        rating: 8.0,
        isFavorite: false,
      );

      final updated = m.copyWith(currentChapter: 50, isFavorite: true);
      expect(updated.currentChapter, 50);
      expect(updated.isFavorite, isTrue);
      // Các trường khác giữ nguyên
      expect(updated.title, 'Original');
      expect(updated.totalChapters, 100);
      expect(updated.rating, 8.0);
    });
  });
}
