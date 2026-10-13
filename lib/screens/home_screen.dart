import 'package:flutter/material.dart';
import '../models/manga.dart';
import '../models/user.dart';
import '../models/bookmark.dart';
import '../services/auth_guard.dart';
import '../services/auth_service.dart';
import '../services/services.dart';
import '../services/theme_service.dart';
import '../services/database_helper.dart';
import '../widgets/manga_card.dart';
import '../widgets/bookmark_detail_dialog.dart';
import 'detail_screen.dart';
import 'form_screen.dart';
import 'login_screen.dart';
import 'register_screen.dart';
import 'forgot_password_screen.dart';
import 'user_management_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  final MangaService _service = MangaService.instance;
  final AuthService _auth = AuthService.instance;
  final ThemeService _theme = ThemeService.instance;

  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();

  List<Manga> _allMangas = [];
  List<BookmarkDetail> _userBookmarks = [];
  String _searchQuery = '';
  String _selectedGenre = 'Tất cả';
  bool _isLoading = true;
  bool _isGridView = true; // Mặc định hiển thị dạng lưới bìa Manga chân thực

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });
    _auth.addListener(_onStateChanged);
    _theme.addListener(_onStateChanged);
    _loadMangas();
  }

  void _onStateChanged() {
    if (mounted) {
      _loadBookmarks();
      setState(() {});
    }
  }

  Future<void> _loadBookmarks() async {
    final currentUser = _auth.currentUser;
    if (!currentUser.isGuest) {
      final bookmarks = await DatabaseHelper.instance.getUserBookmarks(currentUser.id);
      if (mounted) {
        setState(() {
          _userBookmarks = bookmarks;
        });
      }
    } else {
      if (mounted) {
        setState(() {
          _userBookmarks = [];
        });
      }
    }
  }

  Future<void> _loadMangas() async {
    setState(() => _isLoading = true);
    final data = await _service.getMangas();
    await _loadBookmarks();
    if (!mounted) return;
    setState(() {
      _allMangas = data;
      _isLoading = false;
    });
  }

  @override
  void dispose() {
    _auth.removeListener(_onStateChanged);
    _theme.removeListener(_onStateChanged);
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

//   Future<void> _loadMangas() async {
//     setState(() => _isLoading = true);
//     final list = await _service.getMangas();
//     setState(() {
//       _allMangas = list;
//       _isLoading = false;
//     });
//   }

  List<Manga> get _filteredMangas {
    return _allMangas.where((m) {
      final matchesSearch = m.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          m.author.toLowerCase().contains(_searchQuery.toLowerCase());
      final matchesGenre = _selectedGenre == 'Tất cả' || m.genre == _selectedGenre;
      return matchesSearch && matchesGenre;
    }).toList();
  }

  List<Manga> get _favoriteMangas {
    return _filteredMangas.where((m) => m.isFavorite).toList();
  }

  List<Manga> get _continueReadingMangas {
    return _allMangas.where((m) => m.currentChapter > 0).toList();
  }

  Manga? get _featuredManga {
    if (_allMangas.isEmpty) return null;
    final list = List<Manga>.from(_allMangas)..sort((a, b) => b.rating.compareTo(a.rating));
    return list.first;
  }

  void _showLoginDialog() {
    final usernameCtrl = TextEditingController();
    final passwordCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool obscurePassword = true;
    bool isLoading = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final theme = Theme.of(context);
          final isDark = theme.brightness == Brightness.dark;

          return Dialog(
            backgroundColor: theme.cardColor,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(
                color: isDark ? const Color(0xFF262A3B) : const Color(0xFFE2E5EE),
              ),
            ),
            insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Header: Icon + Title + Close button
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF6C5CE7).withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(Icons.login_rounded, color: Color(0xFF6C5CE7), size: 22),
                              ),
                              const SizedBox(width: 10),
                              Text(
                                'Đăng Nhập',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: theme.colorScheme.onSurface,
                                ),
                              ),
                            ],
                          ),
                          IconButton(
                            icon: Icon(Icons.close_rounded, color: theme.colorScheme.onSurfaceVariant, size: 20),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            tooltip: 'Đóng',
                            onPressed: () => Navigator.pop(ctx),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Đăng nhập để sử dụng đầy đủ các tính năng',
                        style: TextStyle(fontSize: 13, color: theme.colorScheme.onSurfaceVariant),
                      ),
                      const SizedBox(height: 18),

                      // Username field
                      TextFormField(
                        controller: usernameCtrl,
                        style: TextStyle(color: theme.colorScheme.onSurface),
                        decoration: InputDecoration(
                          labelText: 'Tên đăng nhập',
                          prefixIcon: const Icon(Icons.person_outline_rounded, color: Color(0xFF6C5CE7)),
                          filled: true,
                          fillColor: isDark ? const Color(0xFF161924) : const Color(0xFFE9EDF5),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                        ),
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'Vui lòng nhập tên đăng nhập' : null,
                      ),
                      const SizedBox(height: 14),

                      // Password field
                      TextFormField(
                        controller: passwordCtrl,
                        obscureText: obscurePassword,
                        style: TextStyle(color: theme.colorScheme.onSurface),
                        decoration: InputDecoration(
                          labelText: 'Mật khẩu',
                          prefixIcon: const Icon(Icons.lock_outline_rounded, color: Color(0xFF6C5CE7)),
                          suffixIcon: IconButton(
                            icon: Icon(
                              obscurePassword ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                            onPressed: () => setDialogState(() => obscurePassword = !obscurePassword),
                          ),
                          filled: true,
                          fillColor: isDark ? const Color(0xFF161924) : const Color(0xFFE9EDF5),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                        ),
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'Vui lòng nhập mật khẩu' : null,
                      ),
                      const SizedBox(height: 6),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () {
                            final inputUsername = usernameCtrl.text.trim();
                            Navigator.pop(ctx);
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ForgotPasswordScreen(
                                  initialUsername: inputUsername,
                                ),
                              ),
                            );
                          },
                          style: TextButton.styleFrom(
                            foregroundColor: const Color(0xFF6C5CE7),
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                          ),
                          child: const Text(
                            'Quên mật khẩu?',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Nút Đăng nhập
                      ElevatedButton(
                        onPressed: isLoading
                            ? null
                            : () async {
                                if (!formKey.currentState!.validate()) return;
                                final messenger = ScaffoldMessenger.of(context);
                                final navigator = Navigator.of(ctx);
                                setDialogState(() => isLoading = true);
                                final res = await _auth.login(usernameCtrl.text, passwordCtrl.text);
                                setDialogState(() => isLoading = false);

                                if (res.success) {
                                  navigator.pop();
                                  messenger.showSnackBar(
                                    SnackBar(
                                      content: Text(res.message),
                                      backgroundColor: const Color(0xFF00B894),
                                      behavior: SnackBarBehavior.floating,
                                    ),
                                  );
                                  _loadMangas();
                                } else {
                                  messenger.showSnackBar(
                                    SnackBar(
                                      content: Text(res.message),
                                      backgroundColor: const Color(0xFFD63031),
                                      behavior: SnackBarBehavior.floating,
                                    ),
                                  );
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF6C5CE7),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          elevation: 2,
                        ),
                        child: isLoading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                              )
                            : const Text(
                                'Đăng Nhập',
                                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                              ),
                      ),
                      const SizedBox(height: 16),

                      // Link Đăng ký
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Chưa có tài khoản? ',
                            style: TextStyle(fontSize: 13, color: theme.colorScheme.onSurfaceVariant),
                          ),
                          GestureDetector(
                            onTap: () async {
                              final navigator = Navigator.of(context);
                              Navigator.pop(ctx);
                              final registered = await navigator.push<bool>(
                                MaterialPageRoute(builder: (_) => const RegisterScreen()),
                              );
                              if (registered == true) {
                                _loadMangas();
                              }
                            },
                            child: const Text(
                              'Đăng ký ngay',
                              style: TextStyle(
                                fontSize: 13,
                                color: Color(0xFF6C5CE7),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  void _showProfileDialog() {
    final user = _auth.currentUser;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: theme.cardColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: isDark ? const Color(0xFF2E3440) : const Color(0xFFE2E5EE)),
        ),
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Nút đóng góc trên
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    IconButton(
                      icon: Icon(Icons.close_rounded, color: theme.colorScheme.onSurfaceVariant, size: 20),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      tooltip: 'Đóng',
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),

                // Avatar & Vai trò
                CircleAvatar(
                  radius: 34,
                  backgroundColor: user.role.color.withValues(alpha: 0.18),
                  child: Icon(user.role.icon, size: 36, color: user.role.color),
                ),
                const SizedBox(height: 10),
                Text(
                  user.displayName,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface),
                ),
                const SizedBox(height: 4),
                Text(
                  '@${user.username}',
                  style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 13),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: user.role.color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: user.role.color.withValues(alpha: 0.4)),
                  ),
                  child: Text(
                    'Vai trò: ${user.role.label}',
                    style: TextStyle(color: user.role.color, fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                ),
                const SizedBox(height: 16),

                // Bảng tóm tắt quyền hạn
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF10121A) : const Color(0xFFF1F3F7),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: isDark ? const Color(0xFF262A3B) : const Color(0xFFE2E5EE)),
                  ),
                  child: Column(
                    children: [
                      _buildPermissionRow('Xem & tìm kiếm truyện', true),
                      _buildPermissionRow('Lưu truyện yêu thích', user.role.canFavorite),
                      _buildPermissionRow('Ghi nhớ tiến độ đọc', user.role.canTrackProgress),
                      _buildPermissionRow('Thêm truyện mới', user.role.canAddManga),
                      _buildPermissionRow('Chỉnh sửa truyện', user.role.canEditManga),
                      _buildPermissionRow('Xóa truyện', user.role.canDeleteManga),
                      _buildPermissionRow('Quản trị tài khoản', user.role.canManageUsers),
                    ],
                  ),
                ),
                const SizedBox(height: 18),

                // Các nút hành động
                if (user.role.canManageUsers) ...[
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFE84393),
                      foregroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(44),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.manage_accounts_rounded, size: 20),
                    label: const Text('Quản Lý Người Dùng & Phân Quyền', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    onPressed: () {
                      Navigator.pop(ctx);
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const UserManagementScreen()),
                      );
                    },
                  ),
                  const SizedBox(height: 10),
                ],

                if (user.isGuest)
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6C5CE7),
                      foregroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(44),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.login_rounded, size: 20),
                    label: const Text('Đăng Nhập / Đăng Ký Tài Khoản', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    onPressed: () {
                      Navigator.pop(ctx);
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const LoginScreen()),
                      );
                    },
                  )
                else
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.redAccent,
                      side: const BorderSide(color: Colors.redAccent),
                      minimumSize: const Size.fromHeight(44),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.logout_rounded, size: 20),
                    label: const Text('Đăng Xuất', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                    onPressed: () async {
                      final messenger = ScaffoldMessenger.of(context);
                      Navigator.pop(ctx);
                      await _auth.logout();
                      messenger.showSnackBar(
                        const SnackBar(
                          content: Text('Đã đăng xuất thành công.'),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    },
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPermissionRow(String title, bool allowed) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurface)),
          Icon(
            allowed ? Icons.check_circle_rounded : Icons.cancel_rounded,
            size: 16,
            color: allowed ? const Color(0xFF00B894) : Colors.grey,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final displayMangas = _filteredMangas;
    final displayFavorites = _favoriteMangas;
    final currentUser = _auth.currentUser;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 16,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF6C5CE7), Color(0xFFA29BFE)],
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.auto_stories_rounded, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 10),
            Text(
              'Manga Vault',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 19,
                color: theme.colorScheme.onSurface,
                letterSpacing: -0.3,
              ),
            ),
          ],
        ),
        actions: [
          // Nút chuyển đổi Dark Mode / Light Mode
          IconButton(
            tooltip: isDark ? 'Chuyển sang Chế độ Sáng (Light)' : 'Chuyển sang Chế độ Tối (Dark)',
            icon: Icon(
              isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
              color: isDark ? Colors.amber : const Color(0xFF6C5CE7),
            ),
            onPressed: () => _theme.toggleTheme(),
          ),

          // Nút chuyển đổi chế độ xem Grid (Lưới) / List (Danh sách)
          IconButton(
            tooltip: _isGridView ? 'Chuyển sang xem danh sách' : 'Chuyển sang xem dạng lưới',
            icon: Icon(
              _isGridView ? Icons.view_list_rounded : Icons.grid_view_rounded,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            onPressed: () => setState(() => _isGridView = !_isGridView),
          ),

          // Nút Đăng Nhập khi là Khách hoặc Nút Profile khi đã đăng nhập
          Padding(
            padding: const EdgeInsets.only(right: 14, left: 4),
            child: currentUser.isGuest
                ? ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6C5CE7),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      elevation: 1,
                    ),
                    icon: const Icon(Icons.login_rounded, size: 16),
                    label: const Text('Đăng nhập', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    onPressed: _showLoginDialog,
                  )
                : InkWell(
                    onTap: _showProfileDialog,
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: currentUser.role.color.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: currentUser.role.color.withValues(alpha: 0.4)),
                      ),
                      child: Row(
                        children: [
                          Icon(currentUser.role.icon, size: 16, color: currentUser.role.color),
                          const SizedBox(width: 6),
                          Text(
                            currentUser.role.label,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: currentUser.role.color,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFF6C5CE7),
          indicatorWeight: 3,
          labelColor: const Color(0xFF6C5CE7),
          unselectedLabelColor: theme.colorScheme.onSurfaceVariant,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          tabs: [
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.explore_outlined, size: 18),
                  const SizedBox(width: 6),
                  Text('Khám phá (${displayMangas.length})'),
                ],
              ),
            ),
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.favorite_border_rounded, size: 18),
                  const SizedBox(width: 6),
                  Text('Yêu thích (${displayFavorites.length})'),
                ],
              ),
            ),
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.bookmark_border, size: 18),
                  const SizedBox(width: 6),
                  Text('Bookmark (${_userBookmarks.length})'),
                ],
              ),
            ),
          ],
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1280),
          child: Column(
            children: [
              // Banner thông báo nếu là Khách (Guest)
              if (currentUser.isGuest)
                Container(
                  margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF6C5CE7).withValues(alpha: isDark ? 0.15 : 0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF6C5CE7).withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline_rounded, color: Color(0xFF6C5CE7), size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Bạn đang duyệt với tư cách Khách. Đăng nhập để lưu tủ truyện yêu thích & tiến độ đọc cá nhân.',
                          style: TextStyle(
                            color: theme.colorScheme.onSurface,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF6C5CE7),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        onPressed: _showLoginDialog,
                        child: const Text('Đăng nhập', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ),

              // Thanh tìm kiếm
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: TextField(
                  controller: _searchController,
                  onChanged: (val) => setState(() => _searchQuery = val),
                  style: TextStyle(color: theme.colorScheme.onSurface),
                  decoration: InputDecoration(
                    hintText: 'Tìm kiếm truyện theo tên hoặc tác giả...',
                    hintStyle: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 14),
                    prefixIcon: Icon(Icons.search_rounded, color: theme.colorScheme.onSurfaceVariant),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: Icon(Icons.clear_rounded, color: theme.colorScheme.onSurfaceVariant, size: 20),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _searchQuery = '');
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: isDark ? const Color(0xFF161924) : const Color(0xFFE9EDF5),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),

              // Bộ lọc thể loại
              SizedBox(
                height: 42,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemCount: MangaService.genres.length,
                  itemBuilder: (context, index) {
                    final genre = MangaService.genres[index];
                    final isSelected = _selectedGenre == genre;
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: ChoiceChip(
                        label: Text(genre),
                        selected: isSelected,
                        selectedColor: const Color(0xFF6C5CE7),
                        backgroundColor: isDark ? const Color(0xFF161924) : const Color(0xFFE9EDF5),
                        labelStyle: TextStyle(
                          color: isSelected ? Colors.white : theme.colorScheme.onSurfaceVariant,
                          fontSize: 12,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                        onSelected: (_) => setState(() => _selectedGenre = genre),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 6),

              // Nội dung 2 tab
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : TabBarView(
                        controller: _tabController,
                        children: [
                          // Tab 1: Khám phá tất cả truyện
                          _buildExploreTab(displayMangas),

                          // Tab 2: Tủ sách yêu thích
                          currentUser.isGuest
                              ? _buildGuestPrompt('Tủ sách yêu thích cá nhân', Icons.favorite_border_rounded)
                              : _buildMangaDisplay(
                                  displayFavorites,
                                  emptyMessage: 'Chưa có bộ truyện nào trong tủ sách yêu thích.',
                                  showBannerAndShelf: false,
                                ),

                          // Tab 3: Bookmark
                          currentUser.isGuest
                              ? _buildGuestPrompt('Đánh dấu trang (Bookmark)', Icons.bookmark_border)
                              : _buildBookmarkTab(),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFF6C5CE7),
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: const Text(
          'Thêm Truyện',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        onPressed: () async {
          final canAdd = await AuthGuard.checkPermission(
            context,
            featureName: 'Thêm truyện mới',
            minRole: UserRole.staff,
          );
          if (!context.mounted) return;
          if (!canAdd) return;

          final added = await Navigator.push<bool>(
            context,
            MaterialPageRoute(builder: (_) => const MangaFormScreen()),
          );
          if (added == true) {
            _loadMangas();
          }
        },
      ),
    );
  }

  /// Tab 1: Khám phá truyện với Banner nổi bật & mục Đang đọc gần đây
  Widget _buildExploreTab(List<Manga> mangas) {
    final showSpotlight = _searchQuery.isEmpty && _selectedGenre == 'Tất cả';
    return _buildMangaDisplay(
      mangas,
      emptyMessage: 'Không tìm thấy bộ truyện nào phù hợp với từ khóa.',
      showBannerAndShelf: showSpotlight,
    );
  }

  Widget _buildMangaDisplay(
    List<Manga> mangas, {
    required String emptyMessage,
    required bool showBannerAndShelf,
  }) {
    if (mangas.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.menu_book_outlined, size: 54, color: Colors.grey),
              const SizedBox(height: 12),
              Text(
                emptyMessage,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.grey, fontSize: 14),
              ),
            ],
          ),
        ),
      );
    }

    final theme = Theme.of(context);
    final continueReading = _continueReadingMangas;
    final featured = _featuredManga;

    return RefreshIndicator(
      onRefresh: _loadMangas,
      child: CustomScrollView(
        slivers: [
          // 1. Featured Spotlight Banner (Nếu không tìm kiếm và có truyện nổi bật)
          if (showBannerAndShelf && featured != null)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: _buildSpotlightBanner(featured),
              ),
            ),

          // 2. Shelf "Tiếp tục đọc gần đây" (Nếu người dùng đã bắt đầu đọc ít nhất 1 truyện)
          if (showBannerAndShelf && continueReading.isNotEmpty)
            SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Tiếp tục đọc gần đây',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                        Text(
                          '${continueReading.length} truyện',
                          style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 98,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: continueReading.length,
                      itemBuilder: (context, index) {
                        final m = continueReading[index];
                        return MangaContinueReadingCard(
                          manga: m,
                          onTap: () async {
                            await Navigator.push<bool>(
                              context,
                              MaterialPageRoute(builder: (_) => MangaDetailScreen(mangaId: m.id)),
                            );
                            _loadMangas();
                          },
                          onQuickNextChapter: () async {
                            if (m.currentChapter < m.totalChapters) {
                              await _service.updateChapter(m.id, m.currentChapter + 1);
                              _loadMangas();
                            }
                          },
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 18),
                ],
              ),
            ),

          // 3. Tiêu đề danh sách & nút chuyển đổi chế độ xem
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _selectedGenre == 'Tất cả' ? 'Tất cả truyện tranh' : 'Thể loại: $_selectedGenre',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  Row(
                    children: [
                      Text(
                        '${mangas.length} bộ',
                        style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        _isGridView ? Icons.grid_view_rounded : Icons.view_list_rounded,
                        size: 16,
                        color: const Color(0xFF6C5CE7),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // 4. Danh sách Manga: Hiển thị dạng Grid hoặc List tùy chọn
          if (_isGridView)
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              sliver: SliverLayoutBuilder(
                builder: (context, constraints) {
                  // Tự động tính số cột theo chiều rộng màn hình (Responsive)
                  final width = constraints.crossAxisExtent;
                  int crossAxisCount = 2;
                  if (width > 1150) {
                    crossAxisCount = 6;
                  } else if (width > 900) {
                    crossAxisCount = 4;
                  } else if (width > 600) {
                    crossAxisCount = 3;
                  }

                  return SliverGrid(
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: crossAxisCount,
                      childAspectRatio: 0.65, // Tỷ lệ chuẩn bìa truyện tranh
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 14,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final manga = mangas[index];
                        return MangaGridCard(
                          manga: manga,
                          onTap: () async {
                            await Navigator.push<bool>(
                              context,
                              MaterialPageRoute(builder: (_) => MangaDetailScreen(mangaId: manga.id)),
                            );
                            _loadMangas();
                          },
                          onFavoriteToggle: () => _handleFavoriteToggle(manga.id),
                        );
                      },
                      childCount: mangas.length,
                    ),
                  );
                },
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final manga = mangas[index];
                    return MangaCard(
                      manga: manga,
                      onTap: () async {
                        await Navigator.push<bool>(
                          context,
                          MaterialPageRoute(builder: (_) => MangaDetailScreen(mangaId: manga.id)),
                        );
                        _loadMangas();
                      },
                      onFavoriteToggle: () => _handleFavoriteToggle(manga.id),
                    );
                  },
                  childCount: mangas.length,
                ),
              ),
            ),

          const SliverToBoxAdapter(child: SizedBox(height: 80)),
        ],
      ),
    );
  }

  /// Banner nổi bật (Spotlight / Hero Banner)
  Widget _buildSpotlightBanner(Manga manga) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      height: 180,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Ảnh nền bìa phóng to tạo cảm giác cinematic
            Image.network(
              manga.coverUrl,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => Container(color: Colors.grey[900]),
            ),
            // Gradient phủ mờ nền
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [
                    isDark ? const Color(0xFF0F1017).withValues(alpha: 0.95) : Colors.white.withValues(alpha: 0.95),
                    isDark ? const Color(0xFF0F1017).withValues(alpha: 0.85) : Colors.white.withValues(alpha: 0.85),
                    isDark ? Colors.transparent : Colors.transparent,
                  ],
                  stops: const [0.0, 0.65, 1.0],
                ),
              ),
            ),
            // Nội dung chi tiết trên banner
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  // Ảnh bìa nhỏ bên trái
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.network(
                      manga.coverUrl,
                      width: 95,
                      height: 148,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Container(width: 95, color: Colors.grey),
                    ),
                  ),
                  const SizedBox(width: 16),

                  // Thông tin
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: Colors.amber,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text(
                                'NỔI BẬT NHẤT',
                                style: TextStyle(
                                  color: Colors.black,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Icon(Icons.star_rounded, color: Colors.amber, size: 16),
                            Text(
                              ' ${manga.rating}',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: theme.colorScheme.onSurface,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          manga.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Tác giả: ${manga.author} • ${manga.genre}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          manga.description,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurfaceVariant, height: 1.3),
                        ),
                        const SizedBox(height: 10),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF6C5CE7),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          icon: const Icon(Icons.menu_book_rounded, size: 16),
                          label: Text(
                            manga.currentChapter > 0 ? 'Đọc tiếp Chap ${manga.currentChapter}' : 'Bắt đầu đọc',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                          onPressed: () async {
                            await Navigator.push<bool>(
                              context,
                              MaterialPageRoute(builder: (_) => MangaDetailScreen(mangaId: manga.id)),
                            );
                            _loadMangas();
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleFavoriteToggle(String mangaId) async {
    final canFav = await AuthGuard.checkPermission(
      context,
      featureName: 'Lưu truyện yêu thích',
      minRole: UserRole.reader,
    );
    if (!canFav) return;

    await _service.toggleFavorite(mangaId);
    _loadMangas();
  }

  /// Giao diện khi Khách mở Tab Yêu thích / Bookmark
  Widget _buildGuestPrompt(String title, IconData icon) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 58, color: const Color(0xFF6C5CE7)),
            const SizedBox(height: 14),
            Text(
              title,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface),
            ),
            const SizedBox(height: 8),
            Text(
              'Bạn đang duyệt ở chế độ Khách. Vui lòng đăng nhập hoặc tạo tài khoản Độc giả để lưu trữ các bộ truyện yêu thích và đồng bộ tiến độ đọc.',
              textAlign: TextAlign.center,
              style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 13, height: 1.4),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6C5CE7),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              icon: const Icon(Icons.login_rounded, size: 18),
              label: const Text('Đăng Nhập / Đăng Ký Ngay', style: TextStyle(fontWeight: FontWeight.bold)),
              onPressed: _showLoginDialog,
            ),
          ],
        ),
      ),
    );
  }

  /// Tab Bookmark hiển thị danh sách các bookmark của user
  Widget _buildBookmarkTab() {
    if (_userBookmarks.isEmpty) {
      return const Center(
        child: Text('Bạn chưa đánh dấu trang nào.'),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _userBookmarks.length,
      itemBuilder: (context, index) {
        final detail = _userBookmarks[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            leading: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                detail.coverUrl,
                width: 50,
                height: 70,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(width: 50, color: Colors.grey),
              ),
            ),
            title: Text(
              detail.mangaTitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text('Đang đọc: Chương ${detail.chapterNumber}'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              showDialog(
                context: context,
                builder: (context) => BookmarkDetailDialog(
                  detail: detail,
                  onBookmarkDeleted: () {
                    _loadBookmarks();
                  },
                ),
              );
            },
          ),
        );
      },
    );
  }
}
