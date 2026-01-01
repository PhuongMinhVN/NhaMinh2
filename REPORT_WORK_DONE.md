# BÁO CÁO CẬP NHẬT TÍNH NĂNG - ỨNG DỤNG NHÀ MÌNH (V2)

Tài liệu này tổng hợp lại toàn bộ các thay đổi, tính năng mới và cập nhật cơ sở dữ liệu đã được thực hiện trong phiên làm việc vừa qua để nâng cấp ứng dụng lên phiên bản hỗ trợ **Gia phả thuần Việt** và **Tiện ích Gia đình**.

## 1. Tái cấu trúc Quy trình Tạo Gia Phả
Đã loại bỏ "Wizard 5 bước" cũ rườm rà và thay thế bằng 2 luồng tạo mới riêng biệt, phù hợp với thực tế sử dụng của người Việt:

*   **Tạo Gia Đình (CreateFamilySimplePage)**:
    *   Dành cho quy mô nhỏ (Gia đình hạt nhân: Vợ chồng, con cái).
    *   Mặc định người tạo là Trưởng nam (Chủ hộ).
    *   Nhập liệu nhanh trên 1 màn hình duy nhất.
    *   Tự động thiết lập quan hệ Cha - Con, Vợ - Chồng.

*   **Tạo Dòng Họ (CreateClanPage)**:
    *   Dành cho quy mô lớn (Tộc, Chi, Phái).
    *   Bắt đầu từ việc xác định **Thủy Tổ / Viễn Tổ** (Người đứng đầu dòng họ).
    *   Hỗ trợ nhập danh xưng tôn nghiêm (Viễn Tổ, Cao Tổ, Tằng Tổ...).
    *   Tạo nền tảng để các nhánh/chi khác xin gia nhập (Merge) vào sau này.

## 2. Tính năng Mới: Tiện ích Gia đình
Đã tích hợp thêm các công cụ kết nối thành viên ngay trong trang chi tiết Dòng họ (`ClanTreePage`):

*   **Lịch & Sự kiện Gia đạo (FamilyCalendar)**:
    *   Đã thêm bảng `clan_events`.
    *   Cho phép tạo và nhắc nhở các sự kiện quan trọng: **Giỗ Chạp** (Anniversary), **Hiếu** (Tang lễ), **Hỷ** (Cưới hỏi), **Sinh nhật**, **Họp mặt**.
    *   Hỗ trợ đánh dấu Lịch Âm (Is Lunar Date).
    *   Giao diện hiển thị dạng danh sách ngay cạnh danh sách thành viên.
    *   **Tương tác Sự kiện**:
        *   **Nút Tham Gia**: Cho phép thành viên xác nhận tham gia.
        *   **Xuất PDF**: Tạo báo cáo chi tiết sự kiện và danh sách người tham gia để in ấn.
    *   **Hệ thống Thông báo (NotificationsPage)**:
        *   Tự động bắn thông báo cho toàn bộ thành viên khi có sự kiện mới.
        *   Trang quản lý thông báo tập trung (Thông báo chung + Duyệt yêu cầu).

*   **Trò chuyện Bảo mật (MemberChatPage)**:
    *   Đã thêm bảng `chat_messages`.
    *   Tính năng Chat 1-1 giữa các thành viên có tài khoản liên kết.
    *   **Cơ chế Tự hủy**: Tin nhắn được lập trình tự động hết hạn và biến mất sau **7 ngày** (sử dụng `DEFAULT now() + interval '7 days'`).
    *   Bảo mật quyền riêng tư cho các câu chuyện trong nội bộ gia đình.

## 3. Nâng cấp Giao diện & Hiển thị (UI/UX)
*   **Trang Cây Gia Phả (`ClanTreePage`)**:
    *   Chuyển sang thiết kế **Tabs**: Tách biệt [Thành Viên] và [Sự Kiện & Lịch] giúp giao diện thoáng đãng.
    *   **Graph View**: Hỗ trợ xem dạng sơ đồ cây trực quan bên cạnh dạng danh sách.
    *   Thêm Toolbar tiện ích: Quét QR, Thông báo (Link tới trang mới), Gộp dòng họ.

*   **Trang Chào mừng (`FamilyTreeWelcomePage`)**:
    *   Thiết kế lại hiện đại, đóng vai trò là Hub điều hướng chính.
    *   Lối tắt nhanh: Quét QR tham gia, Nhập ID thủ công.

*   **Dashboard**:
    *   Cập nhật menu điều hướng trỏ đúng vào các luồng tạo mới.

## 4. Cập nhật Cơ sở dữ liệu (Database Schema)
Đã thực hiện các thay đổi sâu trong Supabase để hỗ trợ logic phả hệ Việt Nam:

*   **Bảng `family_members`**:
    *   `relation_type`: Phân loại quan hệ (Huyết thống, Dâu, Rể, Con nuôi).
    *   `generation_title`: Danh xưng vai vế (Cụ, Ông, Bác, Chú...).
    *   `vnccid`: Số căn cước (để định danh duy nhất, tránh trùng lặp khi gộp họ).
    *   `is_maternal`: Đánh dấu thành viên **Bên Ngoại**.
    *   `birth_order`: Thứ tự sinh (Con cả, con thứ...) để sắp xếp cây phả hệ chính xác trái/phải.

*   **Script Sửa lỗi (`fix_schema_error.sql`)**:
    *   Đã xử lý triệt để lỗi `generation expression implies immutable` của Postgres bằng cách chuyển cơ chế tính ngày hết hạn tin nhắn sang `DEFAULT`.

*   **Bảng `event_participants` & `notifications` (`event_participation_schema.sql`)**:
    *   Lưu trữ trạng thái tham gia sự kiện của thành viên.
    *   Hỗ trợ gửi và lưu trữ thông báo hệ thống.

## 5. Các File Quan trọng đã tạo/sửa
*   `lib/pages/notifications_page.dart` (Mới)
*   `lib/event_participation_schema.sql` (Mới)
*   `lib/pages/create_clan_page.dart` (Mới)
*   `lib/pages/create_family_simple_page.dart` (Mới)
*   `lib/widgets/family_calendar.dart` (Mới)
*   `lib/pages/member_chat_page.dart` (Mới)
*   `lib/clan_tree_page.dart` (Sửa lớn)
*   `lib/family_tree_welcome_page.dart` (Sửa lớn)
*   `lib/advanced_genealogy_schema.sql` & `lib/fix_schema_error.sql` (SQL)
