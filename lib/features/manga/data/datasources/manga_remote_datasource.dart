import '../../../../core/network/api_client.dart';
import '../../../../core/constants/api_endpoints.dart';
import '../models/manga_model.dart';

abstract class MangaRemoteDataSource {
  Future<List<MangaModel>> fetchMangas();
  Future<MangaModel> fetchMangaById(String id);
  Future<MangaModel> addManga(MangaModel manga);
  Future<MangaModel> updateManga(MangaModel manga);
  Future<void> deleteManga(String id);
}

class MangaRemoteDataSourceImpl implements MangaRemoteDataSource {
  final ApiClient? apiClient;
  final bool useRealApi;

  MangaRemoteDataSourceImpl({
    this.apiClient,
    this.useRealApi = false,
  });

  // Mock Data phong phú dùng cho Demo & Khởi tạo ban đầu
  final List<MangaModel> _mockDatabase = [
    MangaModel(
      id: 'manga-1',
      title: 'One Piece',
      originalTitle: 'ワンピース',
      author: 'Eiichiro Oda',
      artist: 'Eiichiro Oda',
      description:
          'Gol D. Roger, Vua Hải Tặc huyền thoại đã để lại kho báu vĩ đại nhất One Piece trước khi bị xử tử. Monkey D. Luffy, một cậu bé mang trong mình ước mơ tự do và trở thành Vua Hải Tặc mới, bước vào chuyến hành trình vĩ đại trên đại dương.',
      coverUrl:
          'https://images.unsplash.com/photo-1578632767115-351597cf2477?w=600&auto=format&fit=crop&q=80',
      genres: ['Action', 'Adventure', 'Comedy', 'Fantasy', 'Shounen'],
      status: 'Ongoing',
      totalChapters: 1115,
      currentChapter: 1080,
      rating: 9.8,
      releaseYear: 1997,
      updatedAt: DateTime.now().subtract(const Duration(hours: 3)),
    ),
    MangaModel(
      id: 'manga-2',
      title: 'Solo Leveling',
      originalTitle: '나 혼자만 레벨업',
      author: 'Chugong',
      artist: 'DUBU (REDICE Studio)',
      description:
          'Khi những cánh cổng kết nối thế giới với các hầm ngục quái vật mở ra, những con người thức tỉnh năng lực đặc biệt được gọi là Thợ Săn. Sung Jinwoo, thợ săn yếu nhất cấp E, vô tình nhận được một hệ thống thăng cấp duy nhất vô nhị sau biến cố trong Hầm Ngục Kép.',
      coverUrl:
          'https://images.unsplash.com/photo-1607604276583-eef5d076aa5f?w=600&auto=format&fit=crop&q=80',
      genres: ['Action', 'Fantasy', 'Supernatural'],
      status: 'Completed',
      totalChapters: 200,
      currentChapter: 200,
      rating: 9.6,
      releaseYear: 2018,
      updatedAt: DateTime.now().subtract(const Duration(days: 1)),
    ),
    MangaModel(
      id: 'manga-3',
      title: 'Frieren: Beyond Journey\'s End',
      originalTitle: '葬送のフリーレン',
      author: 'Kanehito Yamada',
      artist: 'Tsukasa Abe',
      description:
          'Câu chuyện kể về cuộc sống của pháp sư Frieren sau khi tổ đội anh hùng đã đánh bại Ma Vương. Vì là một Elf sống hàng ngàn năm, cái chết của người đồng đội Himmel đã khiến cô bắt đầu chuyến hành trình mới để tìm hiểu về con người và cảm xúc.',
      coverUrl:
          'https://images.unsplash.com/photo-1534447677768-be436bb09401?w=600&auto=format&fit=crop&q=80',
      genres: ['Adventure', 'Drama', 'Fantasy', 'Slice of Life'],
      status: 'Ongoing',
      totalChapters: 130,
      currentChapter: 95,
      rating: 9.7,
      releaseYear: 2020,
      updatedAt: DateTime.now().subtract(const Duration(days: 2)),
    ),
    MangaModel(
      id: 'manga-4',
      title: 'Jujutsu Kaisen',
      originalTitle: '呪術廻戦',
      author: 'Gege Akutami',
      artist: 'Gege Akutami',
      description:
          'Yuji Itadori nuốt phải ngón tay bị nguyền rủa của Sukuna - Vua Lời Nguyền - để cứu bạn bè. Cậu gia nhập trường trung học Chú Thuật Tokyo để tìm kiếm và thanh tẩy tất cả các phần còn lại của Sukuna trước khi bị xử tử.',
      coverUrl:
          'https://images.unsplash.com/photo-1618336753974-aae8e04506aa?w=600&auto=format&fit=crop&q=80',
      genres: ['Action', 'Supernatural', 'Shounen', 'Horror'],
      status: 'Completed',
      totalChapters: 271,
      currentChapter: 271,
      rating: 9.2,
      releaseYear: 2018,
      updatedAt: DateTime.now().subtract(const Duration(days: 5)),
    ),
    MangaModel(
      id: 'manga-5',
      title: 'Spy x Family',
      originalTitle: 'スパイファミリー',
      author: 'Tatsuya Endo',
      artist: 'Tatsuya Endo',
      description:
          'Một điệp viên tài ba phải lập một gia đình giả tạo để thực hiện nhiệm vụ quốc gia. Trớ trêu thay, người vợ anh cưới là một sát thủ chuyên nghiệp, còn cô con gái nhận nuôi lại có năng lực đọc suy nghĩ của người khác!',
      coverUrl:
          'https://images.unsplash.com/photo-1563089145-599997674d42?w=600&auto=format&fit=crop&q=80',
      genres: ['Action', 'Comedy', 'Slice of Life'],
      status: 'Ongoing',
      totalChapters: 104,
      currentChapter: 72,
      rating: 9.4,
      releaseYear: 2019,
      updatedAt: DateTime.now().subtract(const Duration(days: 3)),
    ),
    MangaModel(
      id: 'manga-6',
      title: 'Blue Lock',
      originalTitle: 'ブルーロック',
      author: 'Muneyuki Kaneshiro',
      artist: 'Yusuke Nomura',
      description:
          'Dự án rèn luyện khắc nghiệt nhất lịch sử bóng đá Nhật Bản: tập hợp 300 tiền đạo trẻ xuất sắc nhất vào một cơ sở biệt lập mang tên Blue Lock để đào tạo ra chân sút ích kỷ và ghi bàn xuất sắc nhất thế giới.',
      coverUrl:
          'https://images.unsplash.com/photo-1518709268805-4e9042af9f23?w=600&auto=format&fit=crop&q=80',
      genres: ['Sports', 'Action', 'Psychological', 'Shounen'],
      status: 'Ongoing',
      totalChapters: 280,
      currentChapter: 250,
      rating: 9.1,
      releaseYear: 2018,
      updatedAt: DateTime.now().subtract(const Duration(days: 4)),
    ),
  ];

  @override
  Future<List<MangaModel>> fetchMangas() async {
    if (useRealApi && apiClient != null) {
      final response = await apiClient!.get(ApiEndpoints.mangas);
      final list = response as List<dynamic>;
      return list.map((e) => MangaModel.fromJson(e as Map<String, dynamic>)).toList();
    }

    // Mô phỏng độ trễ mạng thực tế (Network Latency: 400ms)
    await Future.delayed(const Duration(milliseconds: 400));
    return List<MangaModel>.from(_mockDatabase);
  }

  @override
  Future<MangaModel> fetchMangaById(String id) async {
    if (useRealApi && apiClient != null) {
      final response = await apiClient!.get(ApiEndpoints.mangaDetail(id));
      return MangaModel.fromJson(response as Map<String, dynamic>);
    }

    await Future.delayed(const Duration(milliseconds: 200));
    final item = _mockDatabase.firstWhere(
      (m) => m.id == id,
      orElse: () => throw Exception('Không tìm thấy truyện với ID $id'),
    );
    return item;
  }

  @override
  Future<MangaModel> addManga(MangaModel manga) async {
    if (useRealApi && apiClient != null) {
      final response = await apiClient!.post(
        ApiEndpoints.mangas,
        body: manga.toJson(),
      );
      return MangaModel.fromJson(response as Map<String, dynamic>);
    }

    await Future.delayed(const Duration(milliseconds: 300));
    _mockDatabase.insert(0, manga);
    return manga;
  }

  @override
  Future<MangaModel> updateManga(MangaModel manga) async {
    if (useRealApi && apiClient != null) {
      final response = await apiClient!.put(
        ApiEndpoints.mangaDetail(manga.id),
        body: manga.toJson(),
      );
      return MangaModel.fromJson(response as Map<String, dynamic>);
    }

    await Future.delayed(const Duration(milliseconds: 300));
    final index = _mockDatabase.indexWhere((m) => m.id == manga.id);
    if (index != -1) {
      _mockDatabase[index] = manga;
    }
    return manga;
  }

  @override
  Future<void> deleteManga(String id) async {
    if (useRealApi && apiClient != null) {
      await apiClient!.delete(ApiEndpoints.mangaDetail(id));
      return;
    }

    await Future.delayed(const Duration(milliseconds: 250));
    _mockDatabase.removeWhere((m) => m.id == id);
  }
}
