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