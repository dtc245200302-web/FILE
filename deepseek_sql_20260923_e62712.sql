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