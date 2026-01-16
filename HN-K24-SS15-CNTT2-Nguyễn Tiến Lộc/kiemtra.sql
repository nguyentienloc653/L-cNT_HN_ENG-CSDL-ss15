/*
 * DATABASE SETUP - SESSION 15 EXAM
 * Database: StudentManagement
 */

DROP DATABASE IF EXISTS StudentManagement;
CREATE DATABASE StudentManagement;
USE StudentManagement;

-- =============================================
-- 1. TABLE STRUCTURE
-- =============================================

-- Table: Students
CREATE TABLE Students (
    StudentID CHAR(5) PRIMARY KEY,
    FullName VARCHAR(50) NOT NULL,
    TotalDebt DECIMAL(10,2) DEFAULT 0
);

-- Table: Subjects
CREATE TABLE Subjects (
    SubjectID CHAR(5) PRIMARY KEY,
    SubjectName VARCHAR(50) NOT NULL,
    Credits INT CHECK (Credits > 0)
);

-- Table: Grades
CREATE TABLE Grades (
    StudentID CHAR(5),
    SubjectID CHAR(5),
    Score DECIMAL(4,2) CHECK (Score BETWEEN 0 AND 10),
    PRIMARY KEY (StudentID, SubjectID),
    CONSTRAINT FK_Grades_Students FOREIGN KEY (StudentID) REFERENCES Students(StudentID),
    CONSTRAINT FK_Grades_Subjects FOREIGN KEY (SubjectID) REFERENCES Subjects(SubjectID)
);

-- Table: GradeLog
CREATE TABLE GradeLog (
    LogID INT PRIMARY KEY AUTO_INCREMENT,
    StudentID CHAR(5),
    OldScore DECIMAL(4,2),
    NewScore DECIMAL(4,2),
    ChangeDate DATETIME DEFAULT CURRENT_TIMESTAMP
);

-- =============================================
-- 2. SEED DATA
-- =============================================

-- Insert Students
INSERT INTO Students (StudentID, FullName, TotalDebt) VALUES 
('SV01', 'Ho Khanh Linh', 5000000),
('SV03', 'Tran Thi Khanh Huyen', 0);

-- Insert Subjects
INSERT INTO Subjects (SubjectID, SubjectName, Credits) VALUES 
('SB01', 'Co so du lieu', 3),
('SB02', 'Lap trinh Java', 4),
('SB03', 'Lap trinh C', 3);

-- Insert Grades
INSERT INTO Grades (StudentID, SubjectID, Score) VALUES 
('SV01', 'SB01', 8.5), -- Passed
('SV03', 'SB02', 3.0); -- Failed


select * from gradelog;
select * from grades;
select * from students;
select * from subjects;

-- Câu 1 (Trigger - 2đ): Nhà trường yêu cầu điểm số (Score) nhập vào hệ thống phải luôn hợp lệ (từ 0 đến 10). Hãy viết một Trigger có tên tg_CheckScore chạy trước khi thêm (BEFORE INSERT) dữ liệu vào bảng Grades.
-- Nếu người dùng nhập Score < 0 thì tự động gán về 0.
-- Nếu người dùng nhập Score > 10 thì tự động gán về 10.

delimiter $$
create trigger tg_checkScore
before insert on grades
for each row
begin
if new.score < 0 then
set new.score = 0;
end if;

if new.score > 10 then
set new.score = 10;
end if;


end $$
delimiter ;

insert into grades values
('SV01', 'SB02', 15);

-- Câu 2 (Transaction - 2đ): Viết một đoạn script sử dụng Transaction để thêm một sinh viên mới. Yêu cầu đảm bảo tính trọn vẹn "All or Nothing" của dữ liệu:
-- Bắt đầu Transaction.
-- Thêm sinh viên mới vào bảng Students: StudentID = 'SV02', FullName = 'Ha Bich Ngoc'.
-- Cập nhật nợ học phí (TotalDebt) cho sinh viên này là 5,000,000.
-- Xác nhận (COMMIT) Transaction.

start transaction;
insert into students (StudentID, FullName) values 
('SV02', 'Ha Bich Ngoc');
update students
set totalDebt = 5000000
where studentID = 'SV02';
commit;

-- Câu 3 (Trigger - 1.5đ): Để chống tiêu cực trong thi cử, mọi hành động sửa đổi điểm số cần được ghi lại. Hãy viết Trigger tên tg_LogGradeUpdate chạy sau khi cập nhật (AFTER UPDATE) trên bảng Grades.
-- Yêu cầu: Khi điểm số thay đổi, hãy tự động chèn một dòng vào bảng GradeLog với các thông tin: StudentID, OldScore (lấy từ OLD), NewScore (lấy từ NEW), và ChangeDate là thời gian hiện tại (NOW()).

delimiter $$
create trigger tg_LogGradeUpdate
after update on grades
for each row
begin
if old.score <> new.score then
insert into gradelog (StudentID, OldScore, NewScore, ChangeDate) values
(old.StudentID, old.score, new.score, now());
end if;
end $$

update grades
set score = 9
where studentID = 'SV01' and subjectID = 'SB01' ;


select * from gradelog;


-- Câu 4 (Transaction & Procedure cơ bản - 1.5đ): Viết một Stored Procedure đơn giản tên sp_PayTuition thực hiện việc đóng học phí cho sinh viên 'SV01' với số tiền 2,000,000.
-- Bắt đầu Transaction.
-- Trừ 2,000,000 trong cột TotalDebt của bảng Students (StudentID = 'SV01').
-- Kiểm tra logic: Nếu sau khi trừ, TotalDebt < 0, hãy ROLLBACK để hủy bỏ. Ngược lại, hãy COMMIT.

delimiter $$
create procedure sp_PayTuition()
begin
    declare remainingdebt decimal(10,2);
start transaction;

update students
set totaldebt = totaldebt - 2000000
where studentid = 'SV01';

select totaldebt into remainingdebt
from students
where studentid = 'SV01';

if remainingdebt < 0 then
	rollback;
select 'Thanh toán thất bại' as message;
else
commit;
select 'Thanh toán thành công' as message;
    end if;
end$$
delimiter ;
call sp_paytuition();

-- Câu 5 (Trigger nâng cao - 1.5đ): Viết Trigger tên tg_PreventPassUpdate.
-- Quy tắc nghiệp vụ: Sinh viên đã qua môn (Điểm cũ >= 4.0) thì không được phép sửa điểm nữa để đảm bảo tính minh bạch.
-- Yêu cầu: Viết trigger BEFORE UPDATE trên bảng Grades. Nếu OldScore (OLD.Score) >= 4.0, hãy hủy thao tác cập nhật bằng cách phát sinh lỗi (Sử dụng SIGNAL SQLSTATE với thông báo lỗi tùy ý).

delimiter $$
create trigger tg_preventpassupdate
before update on grades
for each row
begin
if old.score >= 4 then
        signal sqlstate '45000'
        set message_text = 'Khong duoc sua';
end if;
end$$

delimiter ;

-- Sinh viên chưa qua môn
update grades
set score = 5
where studentid = 'SV03' and subjectid = 'SB02'; 

-- Sinh viên đã qua môn
update grades
set score = 9
where studentid = 'SV01' and subjectid = 'SB01';

-- Câu 6 (Stored Procedure & Transaction - 1.5đ): Viết một Stored Procedure tên sp_DeleteStudentGrade nhận vào p_StudentID và p_SubjectID. Thủ tục này thực hiện việc sinh viên xin hủy môn học nhưng phải đảm bảo an toàn dữ liệu:
-- Bắt đầu Transaction.
-- Lưu điểm hiện tại của sinh viên vào bảng GradeLog (Ghi chú: coi như điểm mới NewScore là NULL) để lưu vết trước khi xóa.
-- Thực hiện lệnh xóa (DELETE) dòng dữ liệu tương ứng trong bảng Grades.
-- Kiểm tra: Nếu không tìm thấy dòng dữ liệu nào được xóa (dùng hàm ROW_COUNT() trả về 0), hãy ROLLBACK.
-- Nếu xóa thành công, hãy COMMIT.

delimiter $$

create procedure sp_deletestudentgrade(
    in p_studentid char(5),
    in p_subjectid char(5)
)
begin
declare deleted_rows int;
start transaction;

insert into gradelog(studentid, oldscore, newscore, changedate)
select studentid, score, null, now()
from grades
where studentid = p_studentid
and subjectid = p_subjectid;

delete from grades
where studentid = p_studentid
and subjectid = p_subjectid;

set deleted_rows = row_count();

if deleted_rows = 0 then
	rollback;
	select 'Khong tim thay du lieu de xoa' as message;
else
	commit;
	select 'Xoa diem thanh cong' as message;
end if;

end$$

delimiter ;
call sp_deletestudentgrade('SV03','SB02');