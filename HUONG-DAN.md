# AI INNOVATION 2026 – Hướng dẫn cài đặt và vận hành (bản Supabase)

## 0. Hệ thống đã được cài đặt sẵn

| Mục | Địa chỉ |
|---|---|
| Địa chỉ app cho đảng viên | https://cubisung.github.io/ai-innovation-2026/ |
| Mã nguồn | https://github.com/cubisung/ai-innovation-2026 |
| Quản trị cơ sở dữ liệu | https://supabase.com/dashboard/project/fhmtbkwrewrdxyllktvy |

Đã làm: tạo project Supabase (gói miễn phí, khu vực châu Á – Thái Bình Dương), chạy `001_schema.sql` và `002_storage.sql`, tắt xác nhận email, điền `config.js`, đưa app lên GitHub Pages và khai báo địa chỉ app trong Supabase.

Việc đầu tiên cần làm: **người phụ trách đăng ký tài khoản với vai trò Cấp uỷ** tại địa chỉ app ở trên, trước khi gửi link cho đảng viên. Tài khoản đầu tiên được duyệt và xác nhận Cấp uỷ tự động; từ người thứ hai trở đi phải được Cấp uỷ duyệt trong menu Quản trị.

Phần 1 dưới đây chỉ dùng khi cần cài lại từ đầu hoặc chuyển sang máy chủ khác.

Bộ file gồm:

| File | Nội dung |
|---|---|
| `index.html` | Toàn bộ ứng dụng (giao diện + xử lý phía trình duyệt) |
| `config.js` | Nơi điền địa chỉ và khóa công khai của Supabase |
| `supabase/001_schema.sql` | Bảng dữ liệu, phân quyền RLS, các hàm nghiệp vụ |
| `supabase/002_storage.sql` | Kho tệp minh chứng và quyền xem/tải |
| `supabase/tests/` | Bộ kiểm thử phân quyền (dùng cho PostgreSQL thử nghiệm, không chạy trên Supabase thật) |

## 1. Cài đặt lại từ đầu (khi cần)

1. Vào supabase.com, tạo tài khoản và một **project mới** (chọn khu vực Singapore).
2. Mở **SQL Editor**, dán toàn bộ nội dung `supabase/001_schema.sql`, bấm Run. Làm tương tự với `supabase/002_storage.sql`.
3. Mở **Authentication → Sign In / Providers → Email**, tắt **Confirm email** để đảng viên đăng ký xong dùng được ngay. Nếu để bật, mỗi người phải bấm link trong thư xác nhận, và dịch vụ gửi thư mặc định của Supabase chỉ gửi được rất ít thư mỗi giờ.
4. Mở **Project Settings → API**, chép **Project URL** và **anon public key** vào `config.js`. Không dán `service_role` key vào bất kỳ file nào của ứng dụng.
5. Đưa hai file `index.html` và `config.js` (cùng một thư mục) lên một nơi lưu trữ web tĩnh: Netlify, Vercel, GitHub Pages hoặc máy chủ web nội bộ. Ứng dụng không cần bước build.
6. Mở **Authentication → URL Configuration**, điền địa chỉ trang vừa tạo vào **Site URL**.

## 2. Tài khoản và phân quyền

- Mỗi người tự đăng ký bằng email, mật khẩu, User AD, Chi bộ (1, 2, 3) và vai trò (Đảng viên hoặc Cấp uỷ).
- **Tài khoản Cấp uỷ đầu tiên của hệ thống được duyệt và xác nhận tự động.** Vì vậy người phụ trách cần đăng ký ngay sau khi cài đặt, trước khi gửi link cho người khác.
- **Tài khoản mới phải được Cấp uỷ duyệt** ở menu Quản trị thì mới xem được dữ liệu. Nhờ đó người ngoài có được link cũng không vào được.
- **Danh sách đảng viên**: Cấp uỷ nhập file Excel (cột User AD, Họ tên, Phòng ban, Chi bộ, Chức vụ, Vai trò) ở menu Quản trị. Người đăng ký có User AD trùng danh sách được duyệt tự động, thông tin lấy theo danh sách. Tổng số đảng viên trên Tổng quan và Báo cáo tính cả người trong danh sách chưa tạo tài khoản.
- Tài khoản chọn vai trò Cấp uỷ (kể cả theo danh sách) vẫn phải được một cấp uỷ hiện có xác nhận. Trong lúc chờ, họ dùng như đảng viên.
- Cấp uỷ cũng đăng ký cam kết, sáng kiến như đảng viên. Người duyệt là cấp uỷ khác cùng Chi bộ. Nếu Chi bộ không còn cấp uỷ nào khác thì cấp uỷ Chi bộ khác duyệt thay.
- Menu **Quản trị** (chỉ Cấp uỷ): duyệt tài khoản, xác nhận cấp uỷ, chuyển cấp uỷ thành đảng viên, khóa/mở khóa, nhập danh sách đảng viên, xem nhật ký thao tác, tải bản sao dữ liệu.
- **Quên mật khẩu**: bấm "Quên mật khẩu" ở màn hình đăng nhập để nhận thư đặt lại. Dịch vụ gửi thư mặc định của Supabase chỉ gửi được vài thư mỗi giờ; nếu không nhận được thư, người quản trị đặt lại trong Supabase → Authentication → Users. Đổi mật khẩu khi đã đăng nhập: bấm vào tên ở góc trên.

## 3. Quy trình nghiệp vụ

1. Đảng viên tick cam kết, thêm một hoặc nhiều sáng kiến (đúng một sáng kiến chính), bấm **Gửi đăng ký**.
2. Cấp uỷ **xác nhận** (cam kết và sáng kiến duyệt chung một lần) hoặc **yêu cầu bổ sung**.
3. Sau khi được xác nhận, giai đoạn 1 hoàn thành (20%). Đảng viên cập nhật giai đoạn 2 → 5; mỗi giai đoạn cần ít nhất một cập nhật có minh chứng (đường dẫn hoặc tệp tối đa 10 MB) rồi mới gửi xác nhận.
4. Cấp uỷ xác nhận từng giai đoạn; mỗi giai đoạn được xác nhận cộng 20%. Xác nhận giai đoạn 5 là hoàn thành, sáng kiến vào **Thư viện**.
5. Lịch sử cập nhật, minh chứng, nhận xét không sửa và không xóa được từ ứng dụng.

"Quá hạn" được tính tự động khi qua thời hạn mà chưa hoàn thành. "Nguy cơ chậm" là còn từ 14 ngày trở xuống mà tiến độ dưới 80%, hoặc 30 ngày chưa cập nhật.

## 4. Bảo mật

- Mọi bảng bật RLS và chỉ cho đọc. Mọi thao tác ghi đi qua hàm trong cơ sở dữ liệu, hàm tự kiểm tra quyền, nên không thể vượt quyền bằng cách gọi thẳng API.
- Người chưa đăng nhập không đọc được dữ liệu (trừ danh mục tên Chi bộ, phòng ban dùng cho form đăng ký). Tài khoản chưa được duyệt hoặc bị khóa không đọc và không ghi được.
- Bản nháp chỉ chủ sở hữu thấy. Tệp minh chứng: chủ sáng kiến và Cấp uỷ xem được; mọi đảng viên xem được khi sáng kiến đã hoàn thành.
- Không nhập dữ liệu khách hàng, CIF, số tài khoản, hồ sơ tín dụng.
- Supabase Cloud là hạ tầng bên ngoài. Trước khi dùng chính thức cần được VietinBank phê duyệt, hoặc chuyển sang Supabase tự cài trên máy chủ nội bộ (dùng lại nguyên hai file SQL).

## 5. Sao lưu và khôi phục

- Tải bản sao JSON định kỳ ở menu Quản trị; xuất Excel hoặc In / Lưu PDF ở menu Báo cáo.
- Sao lưu/khôi phục cơ sở dữ liệu thực hiện trong Supabase (Database → Backups). Gói miễn phí có giới hạn về sao lưu tự động và có thể tạm dừng project khi lâu không dùng; kiểm tra chính sách hiện hành của Supabase.

## 6. Đã kiểm thử và chưa kiểm thử

Đã chạy trên PostgreSQL 16 thử nghiệm (có giả lập phần đăng nhập của Supabase):

- `supabase/tests/rls_test.sql`: 42 phép kiểm tra phân quyền và nghiệp vụ, tất cả đạt (không ghi trực tiếp được vào bảng, không tự duyệt, tài khoản chưa duyệt không đọc được gì, đảng viên/cấp uỷ chưa xác nhận không duyệt được, không gửi giai đoạn khi thiếu minh chứng, trùng danh sách không tự nâng quyền, tài khoản khóa và người chưa đăng nhập không đọc được dữ liệu...).
- Chạy giao diện tự động nối với cơ sở dữ liệu thử nghiệm (24 bước): đăng ký → chờ duyệt → cấp uỷ duyệt tài khoản → lưu nháp → gửi → cấp uỷ duyệt → cập nhật + minh chứng → xác nhận giai đoạn → báo cáo, nhật ký. Tất cả đạt.
- Đã xem ảnh chụp giao diện ở chiều rộng máy tính và điện thoại (390 px).

Chưa kiểm thử được vì cần project Supabase thật: đăng nhập/đăng ký và thư đặt lại mật khẩu qua Supabase Auth, tải và mở tệp minh chứng (`002_storage.sql`), nhập file Excel danh sách, in PDF trên trình duyệt thật, hiển thị trên iPhone thật. Sau khi cài, hãy thử lần lượt: đăng ký 2 tài khoản, gửi và duyệt một sáng kiến, tải một tệp minh chứng rồi mở lại bằng tài khoản khác.

## 7. Chưa có trong bản này

Thông báo qua email khi có việc cần duyệt (app nhắc việc ngay trong màn hình: mục "Việc cần bạn xử lý" ở Tổng quan và số việc trên menu; gửi email cần thêm một dịch vụ gửi thư bên ngoài); tự động cập nhật màn hình khi người khác thay đổi (app nạp lại dữ liệu sau mỗi thao tác và khi quay lại trang sau 1 phút).
