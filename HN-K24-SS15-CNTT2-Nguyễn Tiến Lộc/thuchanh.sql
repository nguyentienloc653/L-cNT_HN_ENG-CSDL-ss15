create database session15;
use session15;

create table users(
	user_id int primary key auto_increment,
    username varchar(50) unique not null,
    password varchar(255) not null,
    email varchar(100) unique not null,
    created_at datetime default current_timestamp
);

create table posts(
	post_id int primary key auto_increment,
    user_id int,
    content text,
    created_at datetime default current_timestamp,
    
    foreign key(user_id) references users(user_id) on delete cascade
);

create table comments(
	comment_id int primary key auto_increment,
    post_id int,
    user_id int,
    content text,
    created_at datetime default current_timestamp,
    
    foreign key(post_id) references posts(post_id) on delete cascade,
    foreign key(user_id) references users(user_id) on delete cascade
);

create table likes(
	user_id int,
    post_id int,
    created_at datetime default current_timestamp,
    
    primary key(user_id, post_id),
    foreign key(user_id) references users(user_id) on delete cascade,
    foreign key(post_id) references posts(post_id) on delete cascade
);

create table friends(
	user_id int,
    friend_id int,
    status enum("pending", "accepted") default "pending",
    created_at datetime default current_timestamp,
	
    primary key(user_id, friend_id),
    foreign key(user_id) references users(user_id) on delete cascade,
    foreign key(friend_id) references users(user_id) on delete cascade
);

create table user_logs(
	log_id int primary key auto_increment,
    user_id int,
    action text,
    log_time datetime default current_timestamp
);

create table post_logs(
	log_id int primary key auto_increment,
    post_id int,
    user_id int,
    action varchar(100),
    log_time datetime default current_timestamp
);

create table friend_logs(
	log_id int primary key auto_increment,
    sender_id int,
    receiver_id int,
    action varchar(50),
    log_time datetime default current_timestamp
);

-- Bài 1: Đăng Ký Thành Viên
delimiter $$
 create procedure sp_register_user(
	p_username varchar(50),
    p_password varchar(255),
    p_email varchar(100)
)
begin
	declare count_check int;
	-- Kiểm tra trùng username
    select count(*) into count_check from users
    where username = p_username;
    if count_check > 0 then
		signal sqlstate '45000'
        set message_text = "Username đã tồn tại";
	end if;
    -- Kiểm tra trùng email
    select count(*) into count_check from users
    where email = p_email;
    if count_check > 0 then
		signal sqlstate '45000'
        set message_text = "Username đã tồn tại";
    end if;
    -- Thêm người dùng 
	insert into users(username, password, email) 
    values(p_username, p_password, p_email);
end $$
delimiter ;

-- Trigger tự động ghi log user
delimiter $$
create trigger triggerAfterInserUser
after insert on users
for each row
begin
	insert into user_logs(user_id, action) 
    values(new.user_id, "Đăng ký tài khoản");
end $$
delimiter ; 

drop procedure sp_register_user;
drop trigger triggerAfterInserUser;

-- Kiểm thử
call sp_register_user('son01', '123456', 'son01@gmail.com');
call sp_register_user('son02', '123456', 'son02@gmail.com');
call sp_register_user('son03', '123456', 'son03@gmail.com');

select * from users;
select * from user_logs;

-- Bài 2: Đăng Bài Viết
delimiter $$
create procedure sp_create_post(
	p_user_id int,
    p_content text
)
begin
	-- Kiểm tra content rỗng
    if p_content is null or trim(p_content) = "" then
		signal sqlstate '45000'
        set message_text = "Nội dung bài viết không được rỗng";
	end if;
    -- Thêm bài viết
    insert into posts(user_id, content)
    values(p_user_id, p_content);
end $$
delimiter ;
 
delimiter $$
create trigger triggerAfterInsertPost
after insert on posts
for each row
begin
	insert into post_logs(post_id, user_id, action)
    values (new.post_id, new.user_id, "Đăng bài viết");
end $$
delimiter ; 
 
drop procedure sp_create_post;
drop trigger triggerAfterInsertPost;

-- Thêm dữ liệu 
call sp_create_post(1, 'Bài viết số 1');
call sp_create_post(1, 'Bài viết số 2');
call sp_create_post(2, 'Hello mọi người');
call sp_create_post(2, 'Hôm nay học MySQL');
call sp_create_post(3, 'Trigger hoạt động tốt');
call sp_create_post(3, 'Stored Procedure khá hay');

select * from posts;
select * from post_logs;

-- Bài 3: Thích Bài Viết
-- Thêm cột like_count cho post
alter table posts
add column like_count int default 0;

-- Trigger tăng like count của bài viết sau khi like
delimiter $$
create trigger triggerAfterInsertLike
after insert on likes
for each row
begin
	update posts
    set like_count = like_count + 1
    where post_id = new.post_id;
end $$
delimiter ;

-- Trigger giảm like của bài viết sau khi unlike
delimiter $$
create trigger triggerAfterDeleteLike
after delete on likes
for each row
begin
	update posts
    set like_count = like_count - 1
    where post_id = old.post_id;
end $$
delimiter ;

drop trigger triggerAfterInsertLike;
drop trigger triggerAfterDeleteLike;

-- Thêm dữ liệu
insert into likes(user_id, post_id) values (2, 1);
insert into likes(user_id, post_id) values (3, 1);
insert into likes(user_id, post_id) values (1, 2);

select * from posts;
select * from likes;

-- Xóa dữ liệu 
delete from likes
where user_id = 2
  and post_id = 1;

select * from posts;
select * from likes; 

-- Bài 4: Gửi Lời Mời Kết Bạn
delimiter $$
create procedure sp_send_friend_request(
	p_sender_id int,
    p_receiver_id int
)
begin
	declare count_check int;
    -- Kiểm tra tự gửi
    if p_sender_id = p_receiver_id then
		signal sqlstate '45000'
        set message_text = 'Không thể gửi lời mời cho chính mình';
    end if;
    -- Kiểm tra trùng
    select count(*) into count_check from friends
    where user_id = p_sender_id and friend_id = p_receiver_id;
    if count_check > 0 then
		signal sqlstate '45000'
        set message_text = 'Đã gửi lời mới trước đó';
	end if;
    -- Gửi lời mời
    insert into friends(user_id, friend_id)
	values (p_sender_id, p_receiver_id);
end $$
delimiter ;

delimiter $$
create trigger triggerAfterInsertFriend
after insert on friends
for each row
begin
	insert into friend_logs(sender_id, receiver_id, action)
    values (new.user_id, new.friend_id, 'Gửi lời mời kết bạn');
end $$
delimiter ;


drop procedure sp_send_friend_request;
drop trigger triggerAfterInsertFriend;

call sp_send_friend_request(1, 2);
call sp_send_friend_request(1, 3);
call sp_send_friend_request(2, 3);

select * from friends;
select * from friend_logs;

-- Bài 5: Chấp Nhận Lời Mời Kết Bạn
delimiter $$

create procedure sp_accept_friend_request(
	p_sender_id int,
    p_receiver_id int
)
begin
	declare count_check int;
	-- Kiểm tra pending
	select count(*) into count_check
	from friends
	where user_id = p_sender_id
	  and friend_id = p_receiver_id
	  and status = 'pending';

	if count_check = 0 then
		signal sqlstate '45000'
        set message_text = 'Không tồn tại lời mời hợp lệ';
	end if;

	-- Update chiều gửi
	update friends
	set status = 'accepted'
	where user_id = p_sender_id
	  and friend_id = p_receiver_id;

	-- Insert chiều ngược
	insert into friends(user_id, friend_id, status)
	values (p_receiver_id, p_sender_id, 'accepted');
end $$
delimiter ;

drop procedure sp_accept_friend_request;

-- Thêm dữ liệu
call sp_accept_friend_request(1, 2);

select * from friends;

-- Bài 6: Quản Lý Mối Quan Hệ Bạn Bè
delimiter $$
create procedure sp_unfriend(
	p_user_id int,
    p_friend_id int
)
begin
	declare count_check int;
    
	start transaction;
	-- Kiểm tra quan hệ tồn tại
	select count(*) into count_check
	from friends
	where user_id = p_user_id
	  and friend_id = p_friend_id
	  and status = 'accepted';

	if count_check = 0 then
		rollback;
		signal sqlstate '45000'
        set message_text = 'Không tồn tại quan hệ bạn bè';
	end if;

	-- Xóa 2 chiều
	delete from friends
	where (user_id = p_user_id and friend_id = p_friend_id)
	   or (user_id = p_friend_id and friend_id = p_user_id);
       
	commit;
end $$
delimiter ;
 
drop procedure sp_unfriend;

call sp_unfriend(1, 2);

select * from friends;

-- Bài 7: Quản Lý Xóa Bài Viết
delimiter $$

create procedure sp_delete_post(
	p_post_id int,
    p_user_id int
)
begin
	declare count_check int;

	start transaction;
	-- Kiểm tra bài viết tồn tại và đúng chủ
	select count(*) into count_check
	from posts
	where post_id = p_post_id
	  and user_id = p_user_id;

	if count_check = 0 then
		rollback;
		signal sqlstate '45000'
        set message_text = 'Đã xảy lỗi vui lòng thử lại!';
	end if;

	-- Xóa bài viết
	delete from posts
	where post_id = p_post_id;
	commit;
end $$
delimiter ;
 
drop procedure sp_delete_post;

call sp_delete_post(1, 1);

select * from posts;
select * from likes;
select * from comments;

-- Bài 8:
delimiter $$
create procedure sp_delete_user(
	p_user_id int
)
begin
	declare count_check int;

	start transaction;
	-- Kiểm tra user tồn tại
	select count(*) into count_check
	from users
	where user_id = p_user_id;

	if count_check = 0 then
		rollback;
		signal sqlstate '45000'
        set message_text = 'User không tồn tại';
	end if;

	-- Xóa users
	delete from users
	where user_id = p_user_id;
	commit;
end $$
delimiter ;
 
drop procedure sp_delete_user;

call sp_delete_user(1);

select * from users;
select * from posts;
select * from comments;
select * from likes;
select * from friends;