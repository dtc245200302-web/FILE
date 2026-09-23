-- ============================================================
-- PAYFLOW OPTIMIZED SCRIPT
-- Tối ưu hóa truy vấn báo cáo Kế toán bị treo hệ thống
-- Tác giả: Database Performance Engineer
-- Ngày: 2026-09-23
-- ============================================================

USE payflow_db;

-- ============================================================
-- PHẦN 1: TẠO BẢNG (giả lập cấu trúc gốc)
-- ============================================================
-- Bảng Transactions đã có sẵn 5,000,000 dòng dữ liệu
-- CREATE TABLE Transactions (
--     transaction_id INT AUTO_INCREMENT PRIMARY KEY,
--     user_id INT,
--     amount DECIMAL(15,2),
--     transaction_type VARCHAR(20),
--     created_at DATETIME
-- );

-- ============================================================
-- PHẦN 2: TẠO COMPOSITE INDEX
-- ============================================================
-- Index kết hợp trên 2 cột: transaction_type và created_at
-- Thứ tự: transaction_type (selectivity cao) → created_at (range)
-- ============================================================

CREATE INDEX idx_type_date 
ON Transactions(transaction_type, created_at);

-- ============================================================
-- PHẦN 3: EXPLAIN CÂU TRUY VẤN CŨ (LỖI - NON-SARGABLE)
-- ============================================================
-- Mục đích: Chứng minh Full Table Scan (type = ALL)
-- Kỳ vọng: type = ALL, rows ~ 5,000,000, key = NULL
-- ============================================================

EXPLAIN 
SELECT SUM(amount) AS total_deposit
FROM Transactions
WHERE transaction_type = 'DEPOSIT' 
  AND YEAR(created_at) = 2026 
  AND MONTH(created_at) = 6;

-- ============================================================
-- PHẦN 4: EXPLAIN CÂU TRUY VẤN MỚI (ĐÃ TỐI ƯU - SARGABLE)
-- ============================================================
-- Mục đích: Chứng minh Index được sử dụng (type = range)
-- Kỳ vọng: type = range, key = idx_type_date, rows giảm mạnh
-- ============================================================

EXPLAIN 
SELECT SUM(amount) AS total_deposit
FROM Transactions
WHERE transaction_type = 'DEPOSIT' 
  AND created_at >= '2026-06-01 00:00:00' 
  AND created_at <  '2026-07-01 00:00:00';

-- ============================================================
-- PHẦN 5: TRUY VẤN ĐÃ TỐI ƯU (DÙNG ĐỂ CHẠY THỰC TẾ)
-- ============================================================
-- Thay thế YEAR()/MONTH() bằng khoảng thời gian >= và <
-- Giúp MySQL sử dụng được B-Tree Index → giảm từ 45s xuống <1s
-- ============================================================

SELECT SUM(amount) AS total_deposit
FROM Transactions
WHERE transaction_type = 'DEPOSIT' 
  AND created_at >= '2026-06-01 00:00:00' 
  AND created_at <  '2026-07-01 00:00:00';

-- ============================================================
-- PHẦN 6: KIỂM TRA KẾT QUẢ (TÙY CHỌN)
-- ============================================================
-- Đo thời gian thực thi để so sánh trước/sau
-- ============================================================

-- Bật profiling
SET profiling = 1;

-- Chạy truy vấn tối ưu
SELECT SUM(amount) AS total_deposit
FROM Transactions
WHERE transaction_type = 'DEPOSIT' 
  AND created_at >= '2026-06-01 00:00:00' 
  AND created_at <  '2026-07-01 00:00:00';

-- Xem thời gian thực thi
SHOW PROFILES;

-- ============================================================
-- PHẦN 7: KIỂM TRA INDEX ĐÃ TẠO
-- ============================================================
-- Liệt kê tất cả Index trên bảng Transactions
-- ============================================================

SHOW INDEX FROM Transactions;

-- ============================================================
-- PHẦN 8: DỌN DẸP (NẾU CẦN)
-- ============================================================
-- Xóa Index nếu muốn rollback
-- ============================================================

-- DROP INDEX idx_type_date ON Transactions;

-- ============================================================
-- KẾT THÚC SCRIPT
-- ============================================================
# Phân tích EXPLAIN: Trước và Sau tối ưu

## 1. Trước tối ưu (Non-SARGable)

Câu truy vấn gốc bọc hàm `YEAR()` và `MONTH()` quanh cột `created_at`:

- **type = ALL**: MySQL quét toàn bộ bảng 5 triệu dòng.
- **possible_keys = NULL**: Không có Index nào được xem xét.
- **key = NULL**: Không dùng được Index.
- **rows ≈ 5,000,000**: Phải đọc từng dòng, tính YEAR/MONTH.
- **Hệ quả**: CPU 100%, mất 45 giây, khóa bảng, timeout.

## 2. Sau tối ưu (SARGable + Composite Index)

Đã tạo `idx_type_date(transaction_type, created_at)` và viết lại truy vấn dùng khoảng `>=` và `<`:

- **type = range**: MySQL dùng B-Tree Index quét theo khoảng.
- **possible_keys = idx_type_date**: Index được xem xét.
- **key = idx_type_date**: Index được chọn đúng.
- **rows ≈ vài nghìn**: Giảm hàng trăm lần so với ban đầu.
- **Extra = Using index condition**: Lọc trên Index trước khi đọc bảng.

## 3. Kết luận

Việc loại bỏ hàm bọc quanh cột và dùng phép so sánh khoảng đã biến
truy vấn từ Non-SARGable thành SARGable. Kết hợp Composite Index giúp
EXPLAIN chuyển từ `type = ALL` sang `type = range`, giảm thời gian
thực thi từ 45 giây xuống dưới 1 giây mà không làm sai lệch kết quả.
# Nhật ký hỏi đáp AI - PayFlow Optimization

**Ngày thực hiện:** 2026-09-23  
**Vai trò:** Database Performance Engineer  
**Mục tiêu:** Tối ưu truy vấn báo cáo Kế toán tại PayFlow

---

## Prompt 1: Non-SARGable và Index

**Câu hỏi:**
Trong MySQL, nếu tôi tạo Index cho cột ngày tháng, nhưng trong 
mệnh đề WHERE tôi lại viết `WHERE YEAR(col) = 2026`, tại sao MySQL 
lại từ chối sử dụng Index và phải quét toàn bộ bảng?

**Trả lời:**
Vì `YEAR(col)` là một hàm bọc quanh cột. MySQL chỉ dùng được B-Tree 
Index khi cột xuất hiện **độc lập** trong điều kiện so sánh. Khi bọc 
hàm, MySQL phải tính giá trị hàm cho **từng dòng** rồi mới so sánh 
→ không thể tận dụng Index → Full Table Scan.

**Bài học:** Tránh bọc hàm quanh cột trong WHERE.

---

## Prompt 2: Thứ tự cột trong Composite Index

**Câu hỏi:**
Khi thiết kế Composite Index `(transaction_type, created_at)`, thứ tự 
các cột có quan trọng không? Nên đặt cột nào trước?

**Trả lời:**
Thứ tự **rất quan trọng**. Quy tắc:
- Cột có **selectivity cao** (nhiều giá trị khác nhau) đặt trước.
- Cột dùng cho **range** (>=, <) đặt sau.
- MySQL chỉ dùng Index khi cột **đầu tiên** xuất hiện trong WHERE.

Với PayFlow: `transaction_type` (chỉ 3 giá trị: DEPOSIT, WITHDRAW, 
TRANSFER nhưng lọc mạnh) đặt trước; `created_at` (range) đặt sau.

**Bài học:** Composite Index hoạt động theo nguyên tắc "leftmost prefix".

---

## Prompt 3: Ý nghĩa cột type trong EXPLAIN

**Câu hỏi:**
Các giá trị trong cột `type` của EXPLAIN (ALL, index, range, ref, 
const) có ý nghĩa gì? Cái nào tốt nhất?

**Trả lời:**
Xếp từ **tệ nhất → tốt nhất**:
- `ALL`: Full Table Scan — quét toàn bộ bảng.
- `index`: Full Index Scan — quét toàn bộ Index.
- `range`: Quét theo khoảng (>=, <, BETWEEN) — dùng Index.
- `ref`: Tra cứu theo giá trị bằng (=) — dùng Index.
- `eq_ref`: Tra cứu 1 dòng duy nhất qua JOIN.
- `const`: Tra cứu hằng số — nhanh nhất.

**Bài học:** Mục tiêu tối ưu là đưa `type` từ `ALL` lên `range` hoặc `ref`.

---

## Prompt 4: Đo thời gian thực thi

**Câu hỏi:**
Làm sao đo thời gian thực thi (Execution Time) của một câu SQL 
thay vì chỉ xem Execution Plan trong MySQL?

**Trả lời:**
Dùng `profiling`:
```sql
SET profiling = 1;
-- Chạy query
SELECT ... ;
-- Xem kết quả
SHOW PROFILES;
