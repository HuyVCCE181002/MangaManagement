à tôi hiểu cái commit r
Tên Branch đặt <type>/<UCID-hoặc-IssueID>-<short-description>
type:
feat/: Dành cho việc làm tính năng mới / Use Case mới.
fix/: Dành cho việc sửa lỗi.
refactor/: Tái cấu trúc code.
hotfix/: Sửa lỗi khẩn cấp trên nhánh Production.
ví dụ: feat/UC-07-add-view-bookmarks-list-feature

Nội dung commit trước khi push
<type>(<UCID/Issue-ID>): <Tên ngắn gọn của công việc> [Thành viên: <Họ tên>]

- UC Name: <Tên Use Case hoặc tính năng>
- Chi tiết: <Mô tả ngắn gọn những gì đã làm hoặc fix>
Ví dụ
feat(UC05-#102): Hoàn thành API lấy danh sách trang và nội dung chương truyện [Thành viên: Lê Thuận Phát]

- UC Name: UC05 - Đọc chương truyện
- Chi tiết: Viết API endpoint trả về danh sách hình ảnh theo chapterId, tối ưu hóa query phân trang và thêm phân quyền check VIP chapter.