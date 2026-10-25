# CÁC SƠ ĐỒ TUẦN TỰ (SEQUENCE DIAGRAMS)
*(Bản dành riêng cho Báo cáo Đồ án, chuẩn học thuật, không chứa Emoji/Icon)*

## 1. Sơ đồ Tuần tự: Đăng nhập Hệ thống
Mô tả quá trình xác thực thông tin định danh của người dùng với cơ sở dữ liệu Firebase.

```mermaid
%%{init: {'theme':'base', 'themeVariables': {'primaryColor':'#ffffff', 'primaryBorderColor':'#000000', 'lineColor':'#000000'}}}%%
sequenceDiagram
    autonumber
    actor User as Người dùng
    participant UI as Giao diện (App)
    participant Auth as Firebase Auth
    participant DB as Firestore DB

    User->>UI: Nhập Email và Mật khẩu
    User->>UI: Bấm nút "Đăng nhập"
    UI->>UI: Kiểm tra định dạng (Validate Form)
    alt Lỗi định dạng nhập
        UI-->>User: Hiện thông báo: "Email/Pass không hợp lệ"
    else Định dạng đúng
        UI->>Auth: Gửi yêu cầu Đăng nhập (Email, Mật khẩu)
        activate Auth
        Auth->>Auth: So khớp thông tin định danh
        alt Thông tin sai
            Auth-->>UI: Lỗi: Sai mật khẩu hoặc chưa đăng ký
            UI-->>User: Hiện thông báo nhắc nhở sai thông tin
        else Xác thực thành công
            Auth-->>UI: Phản hồi Thành công (Cấp phát Token/UID)
            deactivate Auth
            
            UI->>DB: Truy vấn dữ liệu User Profile theo UID
            activate DB
            DB-->>UI: Trả về gói dữ liệu (Tên, Pillar, Ngày tạo...)
            deactivate DB
            
            UI-->>User: Chuyển hướng sang Giao diện Bảng tin (Home)
        end
    end
```

## 2. Sơ đồ Tuần tự: Đăng nhiệm vụ bằng Trí tuệ Nhân tạo (Voice AI)
Mô tả tiến trình nhận diện giọng nói và truyền tải dữ liệu đa kênh thông qua các API ngoại vi một cách bất đồng bộ.

```mermaid
%%{init: {'theme':'base', 'themeVariables': {'primaryColor':'#ffffff', 'primaryBorderColor':'#000000', 'lineColor':'#000000'}}}%%
sequenceDiagram
    autonumber
    actor Poster as Người đăng việc
    participant App as Ứng dụng TaskHero
    participant Audio as Trình thu âm (Local)
    participant DG as API Deepgram (STT)
    participant OA as API OpenAI (LLM)
    participant FS as Firestore Database

    Poster->>App: Nhấn và giữ nút "Ghi âm"
    App->>Audio: Cấp quyền Micro & Bắt đầu thu
    activate Audio
    Audio-->>App: Trạng thái: Đang thu âm...
    
    Poster->>App: Nhả nút "Ghi âm"
    App->>Audio: Ra lệnh kết thúc phiên thu
    Audio-->>App: Trả về luồng âm thanh tệp nhị phân (audioBytes)
    deactivate Audio
    
    App->>DG: Gửi AudioBytes lên máy chủ phân tích
    activate DG
    DG-->>App: Trả về kết quả Văn bản thô (Transcript)
    deactivate DG
    
    App->>OA: Chuyển giao Transcript & Prompt bóc tách
    activate OA
    OA-->>App: Trả về cấu trúc JSON (title, desc, money...)
    deactivate OA
    
    App->>App: Khớp Cấu trúc dữ liệu JSON vào Form xem trước
    App-->>Poster: Hiển thị giao diện Preview form nội dung công việc
    
    Poster->>App: Bấm "Xác nhận & Đăng"
    App->>FS: Thêm Document mới (collection 'tasks')
    activate FS
    FS-->>App: Cờ hiệu thành công (200 OK)
    deactivate FS
    
    App-->>Poster: Hiển thị thông báo hoàn tất tạo nhiệm vụ
```

## 3. Sơ đồ Tuần tự: Nhận nhiệm vụ (Hero Accept Task)
Mô tả quy trình tương tác giữa sinh viên chuyên nhận việc và hệ thống luồng dữ liệu thời gian thực.

```mermaid
%%{init: {'theme':'base', 'themeVariables': {'primaryColor':'#ffffff', 'primaryBorderColor':'#000000', 'lineColor':'#000000'}}}%%
sequenceDiagram
    autonumber
    actor Hero as Người nhận việc
    participant Feed as Giao diện Feed (StreamBuilder)
    participant Detail as Màn hình Chi tiết
    participant DB as Firestore DB

    Hero->>Feed: Kích hoạt ứng dụng và tải luồng dữ liệu
    Feed->>DB: Lắng nghe Stream theo Tình trạng mở (status='open')
    activate DB
    DB-->>Feed: Trả về và Cập nhật danh sách Document mới nhất (Snapshot)
    deactivate DB
    
    Hero->>Feed: Nhận định & Nhấn vào 1 Card Nhiệm vụ mục tiêu
    Feed-->>Hero: Chuyển hướng Navigation sang Màn hình Chi tiết
    
    Hero->>Detail: Đọc dữ liệu mô tả, bấm "Nhận Việc"
    Detail->>DB: Yêu cầu Cập nhật (Update) Document Nhiệm vụ
    activate DB
    Note right of Detail: status = 'accepted'<br>heroId = [Current_UID]
    
    DB->>DB: Ràng buộc an toàn: Kiểm tra Document vẫn đang 'open'
    alt Document đã bị User khác cập nhật trước
        DB-->>Detail: Chặn Giao dịch (Transaction Failed)
        Detail-->>Hero: Thông báo "Rất tiếc người khác đã nhận việc này"
    else Thỏa điều kiện khóa Task
        DB-->>Detail: Phản hồi cập nhật thành công (Write Complete)
        deactivate DB
        Detail-->>Hero: Thông báo "Xác nhận Nhận việc. Hãy tiến đến tọa độ đích"
        Detail->>Feed: Render loại bỏ Document đã nhận khỏi Feed chung
    end
```

## 4. Sơ đồ Tuần tự: Xác nhận Hoàn thành, Cổng VietQR và Giao dịch thanh toán
Mô tả khâu xác nhận quyền lợi chéo giữa hai User (Poster và Hero), hiển thị mã VietQR NAPAS 24/7 chuẩn EMVCo và giao dịch nguyên tử cập nhật số dư, đánh giá sao.

```mermaid
%%{init: {'theme':'base', 'themeVariables': {'primaryColor':'#ffffff', 'primaryBorderColor':'#000000', 'lineColor':'#000000'}}}%%
sequenceDiagram
    autonumber
    actor Hero as Người nhận việc (Hero)
    actor Poster as Người đăng việc (Poster)
    participant App as Ứng dụng TaskHero
    participant VietQR as Cổng VietQR NAPAS
    participant DB as Firestore DB (Document & Transaction)

    Hero->>App: Có mặt tại điểm đích, hoàn tất công việc
    Hero->>App: Bấm nút "Báo cáo Hoàn thành"
    App->>DB: Đánh dấu status = 'completed' (Write)
    activate DB
    DB-->>App: Ghi nhận trạng thái hoàn tất
    deactivate DB
    
    App-->>Poster: UI Poster báo nhắc thời gian thực: "Nhiệm vụ đã hoàn thành, chờ thanh toán"
    
    Poster->>App: Bấm "Thanh toán cho Hero"
    App->>VietQR: Yêu cầu sinh mã QR thanh toán theo chuẩn EMVCo (Số tiền, Nội dung Task)
    activate VietQR
    VietQR-->>App: Trả về URL ảnh VietQR kèm thông tin tài khoản thụ hưởng
    deactivate VietQR
    App-->>Poster: Hiển thị Modal VietQR (Mã QR, Nút 1-chạm sao chép STK & Nội dung)
    
    Poster->>Poster: Dùng ứng dụng Ngân hàng quét QR thanh toán NAPAS 24/7
    Poster->>App: Bấm "Xác nhận đã chuyển khoản"
    
    App->>DB: Bắt đầu giao dịch nguyên tử (Atomic Firebase Transaction - markTaskAsPaid)
    activate DB
    Note right of App: Update Collection 'tasks': isPaid = true<br>Cộng totalEarned & thisMonthEarned cho Hero<br>Cộng totalSpent cho Poster<br>Ghi nhận phí nền tảng 5%
    DB->>DB: Thực thi luồng xử lý toàn vẹn dữ liệu (Atomicity)
    DB-->>App: Kết sổ Giao dịch Thành công toàn phần
    deactivate DB
    
    App-->>Hero: Banner nổi In-App: "Bạn vừa nhận thù lao thành công! 💰"
    App-->>Poster: Hiển thị Dialog Đánh giá & Chấm điểm 1-5 sao kèm nhận xét cho Hero
    
    Poster->>App: Chọn 5 sao + Nhập lời khen ngợi, bấm "Gửi đánh giá"
    App->>DB: Cập nhật rating, totalReviews và reviewComment vào Firestore
```

## 5. Sơ đồ Tuần tự: Hero Hủy nhận việc (Abandon Task & Hoàn trả đơn về Mở)
Mô tả quy trình xử lý ngoại lệ khi Hero đã nhận việc nhưng bận đột xuất hoặc không thể tiếp tục, đảm bảo nhiệm vụ được hoàn trả an toàn lên Feed chung mà không bị mất dữ liệu.

```mermaid
%%{init: {'theme':'base', 'themeVariables': {'primaryColor':'#ffffff', 'primaryBorderColor':'#000000', 'lineColor':'#000000'}}}%%
sequenceDiagram
    autonumber
    actor Hero as Người nhận việc (Hero)
    actor Poster as Người đăng việc (Poster)
    participant App as Ứng dụng TaskHero
    participant DB as Firestore DB

    Hero->>App: Vào Màn hình Chi tiết nhiệm vụ đã nhận
    Hero->>App: Bấm nút "Hủy nhận việc / Trả lại đơn"
    App-->>Hero: Hiển thị Dialog xác nhận & chọn lý do hủy (Bận đột xuất, Sai địa điểm, Khác...)
    
    Hero->>App: Chọn lý do hợp lệ và bấm "Xác nhận Trả lại"
    App->>DB: Gọi hàm abandonTask(taskId, reason)
    activate DB
    Note right of App: Update tasks: status = 'open'<br>heroId = null<br>abandonReason = reason<br>Ghi log tin nhắn hệ thống
    DB->>DB: Khôi phục trạng thái nhiệm vụ về Mở
    DB-->>App: Cập nhật thành công (200 OK)
    deactivate DB
    
    App-->>Hero: Hiển thị Toast "Đã hủy nhận việc thành công"
    App-->>Hero: Chuyển hướng về tab Duyệt nhiệm vụ
    
    DB-->>Poster: Trigger Stream: Trạng thái task chuyển về 'open'
    App-->>Poster: Banner nổi In-App cảnh báo: "Hero đã trả lại nhiệm vụ do: [Lý do]"
    
    DB-->>App: Đẩy lại nhiệm vụ lên Bảng tin (Feed) chung cho các Hero khác nhận
```
