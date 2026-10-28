import 'package:flutter_test/flutter_test.dart';
import 'package:manga_management_app/models/user.dart';

void main() {
  group('AppUser Model - Tests', () {
    test('AppUser tạo đúng với tất cả tham số', () {
      const user = AppUser(
        id: 'u1',
        username: 'testuser',
        displayName: 'Test User',
        password: 'pass123',
        role: UserRole.reader,
      );

      expect(user.id, 'u1');
      expect(user.username, 'testuser');
      expect(user.displayName, 'Test User');
      expect(user.password, 'pass123');
      expect(user.role, UserRole.reader);
    });

    test('UserRole labels hiển thị đúng tiếng Việt', () {
      expect(UserRole.guest.label, 'Khách');
      expect(UserRole.reader.label, 'Độc giả');
      expect(UserRole.staff.label, 'Nhân viên');
      expect(UserRole.admin.label, 'Quản trị viên');
    });

    test('isGuest trả về true chỉ khi role là guest', () {
      const guest = AppUser(
        id: 'g',
        username: 'guest',
        displayName: 'Khách',
        password: '',
        role: UserRole.guest,
      );
      const reader = AppUser(
        id: 'r',
        username: 'reader',
        displayName: 'Reader',
        password: 'p',
        role: UserRole.reader,
      );

      expect(guest.isGuest, isTrue);
      expect(reader.isGuest, isFalse);
    });

    group('Phân quyền (RBAC)', () {
      test('canFavorite - guest thì không, các role khác thì có', () {
        expect(UserRole.guest.canFavorite, isFalse);
        expect(UserRole.reader.canFavorite, isTrue);
        expect(UserRole.staff.canFavorite, isTrue);
        expect(UserRole.admin.canFavorite, isTrue);
      });

      test('canTrackProgress - guest thì không, các role khác thì có', () {
        expect(UserRole.guest.canTrackProgress, isFalse);
        expect(UserRole.reader.canTrackProgress, isTrue);
        expect(UserRole.staff.canTrackProgress, isTrue);
        expect(UserRole.admin.canTrackProgress, isTrue);
      });

      test('canAddManga - chỉ staff và admin', () {
        expect(UserRole.guest.canAddManga, isFalse);
        expect(UserRole.reader.canAddManga, isFalse);
        expect(UserRole.staff.canAddManga, isTrue);
        expect(UserRole.admin.canAddManga, isTrue);
      });

      test('canEditManga - chỉ staff và admin', () {
        expect(UserRole.guest.canEditManga, isFalse);
        expect(UserRole.reader.canEditManga, isFalse);
        expect(UserRole.staff.canEditManga, isTrue);
        expect(UserRole.admin.canEditManga, isTrue);
      });

      test('canDeleteManga - chỉ admin', () {
        expect(UserRole.guest.canDeleteManga, isFalse);
        expect(UserRole.reader.canDeleteManga, isFalse);
        expect(UserRole.staff.canDeleteManga, isFalse);
        expect(UserRole.admin.canDeleteManga, isTrue);
      });

      test('canManageUsers - chỉ admin', () {
        expect(UserRole.guest.canManageUsers, isFalse);
        expect(UserRole.reader.canManageUsers, isFalse);
        expect(UserRole.staff.canManageUsers, isFalse);
        expect(UserRole.admin.canManageUsers, isTrue);
      });

      test('canViewAdminDashboard - chỉ admin', () {
        expect(UserRole.guest.canViewAdminDashboard, isFalse);
        expect(UserRole.reader.canViewAdminDashboard, isFalse);
        expect(UserRole.staff.canViewAdminDashboard, isFalse);
        expect(UserRole.admin.canViewAdminDashboard, isTrue);
      });
    });

    test('toMap() lưu role dạng tên enum (snake_case string)', () {
      const user = AppUser(
        id: 'u1',
        username: 'admin',
        displayName: 'Admin',
        password: 'pw',
        role: UserRole.admin,
      );
      final map = user.toMap();
      expect(map['id'], 'u1');
      expect(map['username'], 'admin');
      expect(map['display_name'], 'Admin');
      expect(map['role'], 'admin');
    });

    test('fromMap() ánh xạ đúng từ SQLite', () {
      final map = {
        'id': 'u2',
        'username': 'staff',
        'display_name': 'Staff',
        'password': 'staff123',
        'role': 'staff',
      };
      final user = AppUser.fromMap(map);
      expect(user.id, 'u2');
      expect(user.displayName, 'Staff');
      expect(user.role, UserRole.staff);
    });

    test('fromMap() chấp nhận cả camelCase displayName', () {
      final map = {
        'id': 'u3',
        'username': 'reader',
        'displayName': 'Reader User',
        'password': 'pw',
        'role': 'reader',
      };
      final user = AppUser.fromMap(map);
      expect(user.displayName, 'Reader User');
      expect(user.role, UserRole.reader);
    });

    test('fromMap() với role không hợp lệ mặc định về reader', () {
      final map = {
        'id': 'u4',
        'username': 'unknown',
        'display_name': 'Unknown',
        'password': 'pw',
        'role': 'superuser', // Không tồn tại
      };
      final user = AppUser.fromMap(map);
      expect(user.role, UserRole.reader);
    });

    test('toJson() / fromJson() làm việc đúng', () {
      const user = AppUser(
        id: 'u5',
        username: 'json_user',
        displayName: 'JSON User',
        password: 'pw',
        role: UserRole.staff,
      );
      final json = user.toJson();
      final restored = AppUser.fromJson(json);
      expect(restored.id, user.id);
      expect(restored.username, user.username);
      expect(restored.displayName, user.displayName);
      expect(restored.role, user.role);
    });

    test('copyWith() chỉ thay đổi trường được chỉ định', () {
      const user = AppUser(
        id: 'u6',
        username: 'old',
        displayName: 'Old',
        password: 'pw',
        role: UserRole.reader,
      );
      final updated = user.copyWith(
        role: UserRole.staff,
        displayName: 'New Name',
      );
      expect(updated.role, UserRole.staff);
      expect(updated.displayName, 'New Name');
      expect(updated.username, 'old'); // giữ nguyên
      expect(updated.id, 'u6'); // giữ nguyên
    });

    test('AppUser.guest là singleton const với role guest', () {
      const g = AppUser.guest;
      expect(g.role, UserRole.guest);
      expect(g.isGuest, isTrue);
      expect(g.password, isEmpty);
    });
  });
}
