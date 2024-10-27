-- Bảng Users: Thông tin người dùng
CREATE TABLE Users (
    UserID INT PRIMARY KEY IDENTITY(1,1),
    Username NVARCHAR(50) NOT NULL UNIQUE,
    PasswordHash VARBINARY(128) NOT NULL,
    FullName NVARCHAR(100),
    Email NVARCHAR(100) NOT NULL UNIQUE,
    Phone NVARCHAR(15),
    Address NVARCHAR(255),
    Role NVARCHAR(20) CHECK (Role IN ('customer', 'admin')),
    CreatedAt DATETIME DEFAULT GETDATE(),
    UpdatedAt DATETIME DEFAULT GETDATE()
);



-- Bảng Categories: Danh mục sách
CREATE TABLE Categories (
    CategoryID INT PRIMARY KEY IDENTITY(1,1),
    CategoryName NVARCHAR(100) NOT NULL UNIQUE,
    Description NVARCHAR(255)
);


-- Bảng Books: Thông tin sách
CREATE TABLE Books (
	CoverImage NVARCHAR(255),  -- Lưu trữ đường dẫn hoặc URL của ảnh
    BookID INT PRIMARY KEY IDENTITY(1,1),
    Title NVARCHAR(255) NOT NULL,
    Author NVARCHAR(255),
    Description NVARCHAR(MAX),
    ISBN NVARCHAR(20) UNIQUE,
    PublishedDate DATE,
    Price DECIMAL(18, 2) NOT NULL,
    StockQuantity INT DEFAULT 0,
    IsAvailableForRent BIT DEFAULT 0,
    RentPrice DECIMAL(18, 2),
    CategoryID INT,
    CreatedAt DATETIME DEFAULT GETDATE(),
    UpdatedAt DATETIME DEFAULT GETDATE(),
    FOREIGN KEY (CategoryID) REFERENCES Categories(CategoryID)
);


-- Bảng Orders: Lưu trữ thông tin đơn hàng
CREATE TABLE Orders (
    OrderID INT PRIMARY KEY IDENTITY(1,1),
    UserID INT,
    TotalAmount DECIMAL(18, 2) NOT NULL,
    OrderDate DATETIME DEFAULT GETDATE(),
    Status NVARCHAR(20) CHECK (Status IN ('pending', 'completed', 'canceled')),
    PaymentMethod NVARCHAR(20),
    FOREIGN KEY (UserID) REFERENCES Users(UserID)
);

-- Bảng OrderDetails: Chi tiết từng đơn hàng
CREATE TABLE OrderDetails (
    OrderDetailID INT PRIMARY KEY IDENTITY(1,1),
    OrderID INT,
    BookID INT,
    Quantity INT NOT NULL,
    Price DECIMAL(18, 2) NOT NULL,
    FOREIGN KEY (OrderID) REFERENCES Orders(OrderID),
    FOREIGN KEY (BookID) REFERENCES Books(BookID)
);

-- Bảng Rentals: Lưu trữ thông tin thuê sách
CREATE TABLE Rentals (
    RentalID INT PRIMARY KEY IDENTITY(1,1),
    UserID INT,
    BookID INT,
    RentalDate DATETIME DEFAULT GETDATE(),
    DueDate DATETIME NOT NULL,
    ReturnDate DATETIME,
    TotalRentalCost DECIMAL(18, 2) NOT NULL,
    Status NVARCHAR(20) CHECK (Status IN ('pending', 'rented', 'returned', 'late')),
    FOREIGN KEY (UserID) REFERENCES Users(UserID),
    FOREIGN KEY (BookID) REFERENCES Books(BookID)
);

ALTER TABLE Rentals
ADD RejectionReason NVARCHAR(255);

ALTER TABLE Rentals
ALTER COLUMN TotalRentalCost DECIMAL(18, 2) NULL;


drop table Rentals


-- Bảng Reviews: Đánh giá sách
CREATE TABLE Reviews (
    ReviewID INT PRIMARY KEY IDENTITY(1,1),
    BookID INT,
    UserID INT,
    Rating INT CHECK (Rating >= 1 AND Rating <= 5),
    Comment NVARCHAR(MAX),
    CreatedAt DATETIME DEFAULT GETDATE(),
    FOREIGN KEY (BookID) REFERENCES Books(BookID),
    FOREIGN KEY (UserID) REFERENCES Users(UserID)
);

-- Bảng Payments: Lưu trữ thông tin thanh toán
CREATE TABLE Payments (
    PaymentID INT PRIMARY KEY IDENTITY(1,1),
    OrderID INT,
    PaymentDate DATETIME DEFAULT GETDATE(),
    PaymentAmount DECIMAL(18, 2) NOT NULL,
    PaymentMethod NVARCHAR(20),
    FOREIGN KEY (OrderID) REFERENCES Orders(OrderID)
);

-- Bảng Cart: Giỏ hàng của người dùng
CREATE TABLE Cart (
    CartID INT PRIMARY KEY IDENTITY(1,1),
    UserID INT,
    BookID INT,
    Quantity INT NOT NULL,
    CreatedAt DATETIME DEFAULT GETDATE(),
    UpdatedAt DATETIME DEFAULT GETDATE(),
    FOREIGN KEY (UserID) REFERENCES Users(UserID),
    FOREIGN KEY (BookID) REFERENCES Books(BookID)
);


---- Bảng thông báo

CREATE TABLE Notifications (
    NotificationID INT IDENTITY(1,1) PRIMARY KEY,  -- Mã thông báo tự động tăng
    UserID INT NOT NULL,                           -- ID người dùng nhận thông báo
    Message NVARCHAR(255) NOT NULL,                -- Nội dung thông báo
    CreatedAt DATETIME DEFAULT GETDATE(),          -- Thời gian tạo thông báo
    IsRead BIT DEFAULT 0,                          -- Trạng thái đã đọc (0 = chưa đọc, 1 = đã đọc)
    FOREIGN KEY (UserID) REFERENCES Users(UserID)  -- Khóa ngoại liên kết với bảng Users
);

ALTER TABLE Notifications ALTER COLUMN UserID INT NULL;


drop table BookRequests



-- Procedures

-- THÊM SÁCH

CREATE PROCEDURE AddBook
    @Title NVARCHAR(255),
    @Author NVARCHAR(255),
    @Description NVARCHAR(MAX),
    @ISBN NVARCHAR(20),
    @PublishedDate DATE,
    @Price DECIMAL(18, 2),
    @StockQuantity INT,
    @IsAvailableForRent BIT,
    @RentPrice DECIMAL(18, 2),
    @CategoryID INT,
    @CoverImage NVARCHAR(255)  -- Tham số mới để nhận đường dẫn ảnh minh họa
AS
BEGIN
    INSERT INTO Books (Title, Author, Description, ISBN, PublishedDate, Price, StockQuantity, IsAvailableForRent, RentPrice, CategoryID, CoverImage)
    VALUES (@Title, @Author, @Description, @ISBN, @PublishedDate, @Price, @StockQuantity, @IsAvailableForRent, @RentPrice, @CategoryID, @CoverImage);
END;



-- THÊM NGƯỜI DÙNG MỚI

CREATE PROCEDURE AddUser
	@AdminUserID INT,
    @Username NVARCHAR(50),
    @PlainPassword NVARCHAR(255),  -- Mật khẩu dạng văn bản thuần
    @FullName NVARCHAR(100),
    @Email NVARCHAR(100),
    @Role NVARCHAR(20)
AS
BEGIN
    -- Kiểm tra xem người dùng là admin hay không
    IF EXISTS (SELECT 1 FROM Users WHERE UserID = @AdminUserID AND Role = 'admin')
    BEGIN
        -- Kiểm tra xem Username đã tồn tại chưa
        IF EXISTS (SELECT 1 FROM Users WHERE Username = @Username)
        BEGIN
            RAISERROR('Username already exists.', 16, 1);
        END
        ELSE
        BEGIN
            -- Mã hóa mật khẩu bằng PWDENCRYPT
            DECLARE @PasswordHash VARBINARY(128);
            SET @PasswordHash = PWDENCRYPT(@PlainPassword);

            -- Thêm người dùng mới với mật khẩu đã mã hóa
            INSERT INTO Users (Username, PasswordHash, FullName, Email, Role)
            VALUES (@Username, @PasswordHash, @FullName, @Email, @Role);
        END
    END
    ELSE
    BEGIN
        RAISERROR('Only admins can add users.', 16, 1);
    END
END;




-- TẠO ĐƠN HÀNG MỚI

CREATE PROCEDURE CreateOrder
    @UserID INT,
    @TotalAmount DECIMAL(18, 2),
    @PaymentMethod NVARCHAR(20)
AS
BEGIN
    INSERT INTO Orders (UserID, TotalAmount, PaymentMethod)
    VALUES (@UserID, @TotalAmount, @PaymentMethod);

    -- Trả về OrderID mới tạo
    SELECT SCOPE_IDENTITY() AS NewOrderID;
END;



-- THÊM CHI TIẾT ĐƠN HÀNG

CREATE PROCEDURE AddOrderDetail
    @OrderID INT,
    @BookID INT,
    @Quantity INT,
    @Price DECIMAL(18, 2)
AS
BEGIN
    INSERT INTO OrderDetails (OrderID, BookID, Quantity, Price)
    VALUES (@OrderID, @BookID, @Quantity, @Price);
END;



-- TẠO GIAO DỊCH THUÊ SÁCH

CREATE PROCEDURE CreateRental
    @UserID INT,
    @BookID INT,
    @DueDate DATETIME,
    @TotalRentalCost DECIMAL(18, 2)
AS
BEGIN
    INSERT INTO Rentals (UserID, BookID, DueDate, TotalRentalCost, Status)
    VALUES (@UserID, @BookID, @DueDate, @TotalRentalCost, 'rented');

    -- Trả về RentalID mới tạo
    SELECT SCOPE_IDENTITY() AS NewRentalID;
END;



-- THÊM SÁCH VÀO GIỎ HÀNG

CREATE PROCEDURE AddToCart
    @UserID INT,
    @BookID INT,
    @Quantity INT
AS
BEGIN
    -- Kiểm tra xem sách đã có trong giỏ hàng chưa
    IF EXISTS (SELECT 1 FROM Cart WHERE UserID = @UserID AND BookID = @BookID)
    BEGIN
        -- Cập nhật số lượng nếu sách đã có trong giỏ hàng
        UPDATE Cart
        SET Quantity = Quantity + @Quantity, UpdatedAt = GETDATE()
        WHERE UserID = @UserID AND BookID = @BookID;
    END
    ELSE
    BEGIN
        -- Thêm mới sách vào giỏ hàng
        INSERT INTO Cart (UserID, BookID, Quantity)
        VALUES (@UserID, @BookID, @Quantity);
    END
END;



-- LẤY GIỎ HÀNG CỦA NGƯỜI DÙNG

CREATE PROCEDURE GetUserCart
    @UserID INT
AS
BEGIN
    SELECT c.CartID, b.BookID, b.Title, c.Quantity, b.Price, (b.Price * c.Quantity) AS TotalPrice
    FROM Cart c
    JOIN Books b ON c.BookID = b.BookID
    WHERE c.UserID = @UserID;
END;



-- XÓA SÁCH KHỎI GIỎ HÀNG

CREATE PROCEDURE RemoveFromCart
    @UserID INT,
    @BookID INT
AS
BEGIN
    DELETE FROM Cart WHERE UserID = @UserID AND BookID = @BookID;
END;



-- THÊM ĐÁNH GIÁ SÁCH

CREATE PROCEDURE AddReview
    @BookID INT,
    @UserID INT,
    @Rating INT,
    @Comment NVARCHAR(MAX)
AS
BEGIN
    INSERT INTO Reviews (BookID, UserID, Rating, Comment)
    VALUES (@BookID, @UserID, @Rating, @Comment);
END;



-- THANH TOÁN ĐƠN HÀNG

CREATE PROCEDURE MakePayment
    @OrderID INT,
    @PaymentAmount DECIMAL(18, 2),
    @PaymentMethod NVARCHAR(20)
AS
BEGIN
    INSERT INTO Payments (OrderID, PaymentAmount, PaymentMethod)
    VALUES (@OrderID, @PaymentAmount, @PaymentMethod);
    
    -- Cập nhật trạng thái đơn hàng thành 'completed'
    UPDATE Orders
    SET Status = 'completed', OrderDate = GETDATE()
    WHERE OrderID = @OrderID;
END;



-- CẬP NHẬT TRẠNG THÁI THUÊ SÁCH (KHI TRẢ SÁCH)

CREATE PROCEDURE ReturnRental
    @RentalID INT
AS
BEGIN
    UPDATE Rentals
    SET Status = 'returned', ReturnDate = GETDATE()
    WHERE RentalID = @RentalID;
END;



-- LẤY TẤT CẢ CÁC ĐƠN HÀNG CỦA NGƯỜI DÙNG

CREATE PROCEDURE GetUserOrders
    @UserID INT
AS
BEGIN
    SELECT o.OrderID, o.TotalAmount, o.OrderDate, o.Status, p.PaymentMethod
    FROM Orders o
    LEFT JOIN Payments p ON o.OrderID = p.OrderID
    WHERE o.UserID = @UserID;
END;



-- LẤY TẤT CẢ CÁC LẦN THUÊ SÁCH CỦA NGƯỜI DÙNG

CREATE PROCEDURE GetUserRentals
    @UserID INT
AS
BEGIN
    SELECT r.RentalID, b.Title, r.RentalDate, r.DueDate, r.ReturnDate, r.TotalRentalCost, r.Status
    FROM Rentals r
    JOIN Books b ON r.BookID = b.BookID
    WHERE r.UserID = @UserID;
END;

exec GetUserRentals 1



-- CẬP NHẬT SỐ LƯỢNG SÁCH KHI BÁN

CREATE PROCEDURE UpdateBookStockAfterOrder
    @OrderID INT
AS
BEGIN
    -- Bắt đầu transaction để đảm bảo tính toàn vẹn dữ liệu
    BEGIN TRANSACTION;
    
    -- Bảng tạm để lưu số lượng sách được đặt trong đơn hàng
    DECLARE @BookOrders TABLE (BookID INT, TotalQuantityOrdered INT);

    -- Lấy số lượng sách đã được đặt từ bảng OrderDetails theo OrderID
    INSERT INTO @BookOrders (BookID, TotalQuantityOrdered)
    SELECT BookID, SUM(Quantity)
    FROM OrderDetails
    WHERE OrderID = @OrderID
    GROUP BY BookID;

    -- Kiểm tra nếu số lượng sách tồn kho đủ để bán
    IF EXISTS (SELECT 1 FROM Books b
               INNER JOIN @BookOrders bo ON b.BookID = bo.BookID
               WHERE b.StockQuantity < bo.TotalQuantityOrdered)
    BEGIN
        -- Phát sinh lỗi nếu không đủ số lượng sách
        RAISERROR('Insufficient stock for order.', 16, 1);
        ROLLBACK TRANSACTION;
        RETURN;
    END

    -- Cập nhật lại số lượng sách tồn kho
    UPDATE Books
    SET StockQuantity = StockQuantity - bo.TotalQuantityOrdered, UpdatedAt = GETDATE()
    FROM Books b
    INNER JOIN @BookOrders bo ON b.BookID = bo.BookID;

    -- Xác nhận transaction nếu cập nhật thành công
    COMMIT TRANSACTION;
END;




CREATE TRIGGER trg_UpdateBookStockAfterOrder
ON OrderDetails
AFTER INSERT
AS
BEGIN
    -- Bảng tạm để lưu tổng số lượng sách đã được đặt trong lần thêm mới
    DECLARE @BookOrders TABLE (BookID INT, TotalQuantityOrdered INT);

    -- Lấy số lượng sách được đặt từ bảng INSERTED (chỉ các bản ghi mới được thêm)
    INSERT INTO @BookOrders (BookID, TotalQuantityOrdered)
    SELECT BookID, SUM(Quantity)
    FROM INSERTED
    GROUP BY BookID;

    -- Cập nhật số lượng sách tồn kho trong bảng Books dựa trên số lượng sách đã được đặt
    UPDATE Books
    SET StockQuantity = StockQuantity - bo.TotalQuantityOrdered,
        UpdatedAt = GETDATE()
    FROM Books b
    INNER JOIN @BookOrders bo ON b.BookID = bo.BookID
    WHERE b.StockQuantity >= bo.TotalQuantityOrdered;

    -- Kiểm tra nếu bất kỳ cuốn sách nào không đủ số lượng để xử lý đơn hàng
    IF EXISTS (SELECT 1 FROM Books b
               INNER JOIN @BookOrders bo ON b.BookID = bo.BookID
               WHERE b.StockQuantity < bo.TotalQuantityOrdered)
    BEGIN
        RAISERROR('Insufficient stock for order.', 16, 1);
        ROLLBACK TRANSACTION;
    END
END;





-- CẬP NHẬT SỐ LƯỢNG SÁCH KHI CHO THUÊ

CREATE PROCEDURE UpdateBookStockAfterNewRentals
    @BookID INT
AS
BEGIN
    -- Bắt đầu transaction để đảm bảo tính toàn vẹn dữ liệu
    BEGIN TRANSACTION;
    
    DECLARE @TotalNewRentals INT;

    -- Đếm số lượng người đã mượn sách từ lần mượn mới (giả sử bảng Rentals chứa bản ghi mới với Status = 'rented')
    SELECT @TotalNewRentals = COUNT(*)
    FROM Rentals
    WHERE BookID = @BookID AND Status = 'rented' AND RentalDate = (SELECT MAX(RentalDate) FROM Rentals WHERE BookID = @BookID);

    -- Kiểm tra nếu số lượng sách tồn kho đủ để cho mượn
    IF EXISTS (SELECT 1 FROM Books WHERE BookID = @BookID AND IsAvailableForRent = 1 AND StockQuantity >= @TotalNewRentals)
    BEGIN
        -- Cập nhật lại số lượng sách tồn kho
        UPDATE Books
        SET StockQuantity = StockQuantity - @TotalNewRentals, UpdatedAt = GETDATE()
        WHERE BookID = @BookID;

        -- Xác nhận transaction nếu cập nhật thành công
        COMMIT TRANSACTION;
    END
    ELSE
    BEGIN
        -- Phát sinh lỗi nếu không đủ số lượng sách
        RAISERROR('Insufficient stock for rental.', 16, 1);
        ROLLBACK TRANSACTION;
    END
END;




CREATE TRIGGER trg_UpdateBookStockAfterRental
ON Rentals
AFTER INSERT
AS
BEGIN
    -- Tạo bảng tạm để lưu tổng số lượng người mượn sách trong lần chèn mới
    DECLARE @BookRentals TABLE (BookID INT, TotalNewRentals INT);

    -- Lấy số lượng người mượn từ bảng INSERTED (chỉ các bản ghi vừa được thêm)
    INSERT INTO @BookRentals (BookID, TotalNewRentals)
    SELECT BookID, COUNT(*)
    FROM INSERTED
    GROUP BY BookID;

    -- Cập nhật lại số lượng sách tồn kho trong bảng Books dựa trên số lượng người mượn mới
    UPDATE Books
    SET StockQuantity = StockQuantity - br.TotalNewRentals,
        UpdatedAt = GETDATE()
    FROM Books b
    INNER JOIN @BookRentals br ON b.BookID = br.BookID
    WHERE b.IsAvailableForRent = 1 AND b.StockQuantity >= br.TotalNewRentals;

    -- Kiểm tra nếu bất kỳ cuốn sách nào không đủ số lượng
    IF EXISTS (SELECT 1 FROM Books b
               INNER JOIN @BookRentals br ON b.BookID = br.BookID
               WHERE b.StockQuantity < br.TotalNewRentals)
    BEGIN
        RAISERROR('Insufficient stock for rental.', 16, 1);
        ROLLBACK TRANSACTION;
    END
END;





-- CẬP NHẬT SỐ LƯỢNG SÁCH KHI NHẬP THÊM VÀO KHO

CREATE PROCEDURE AddStockToBook
    @BookID INT,
    @QuantityAdded INT
AS
BEGIN
    -- Thêm số lượng sách nhập vào kho
    UPDATE Books
    SET StockQuantity = StockQuantity + @QuantityAdded, UpdatedAt = GETDATE()
    WHERE BookID = @BookID;
END;



-- KIỂM TRA ĐĂNG NHẬP

CREATE PROCEDURE UserLogin
    @Username NVARCHAR(50),
    @PlainPassword NVARCHAR(255)  -- Mật khẩu người dùng nhập vào, dạng văn bản thuần
AS
BEGIN
    -- Khai báo biến để lưu mật khẩu đã mã hóa từ cơ sở dữ liệu
    DECLARE @StoredPasswordHash VARBINARY(128);

    -- Lấy mật khẩu mã hóa từ cơ sở dữ liệu theo tên người dùng
    SELECT @StoredPasswordHash = PasswordHash
    FROM Users
    WHERE Username = @Username;

    -- Kiểm tra nếu không tìm thấy tên người dùng
    IF @StoredPasswordHash IS NULL
    BEGIN
        RAISERROR('Invalid username or password.', 16, 1);
        RETURN;
    END

    -- So sánh mật khẩu người dùng nhập vào với mật khẩu mã hóa bằng PWDCOMPARE
    IF PWDCOMPARE(@PlainPassword, @StoredPasswordHash) = 1
    BEGIN
        -- Nếu đúng, trả về thông tin người dùng
        SELECT UserID, Username, FullName, Email, Role
        FROM Users
        WHERE Username = @Username;
    END
    ELSE
    BEGIN
        -- Nếu sai, trả về thông báo lỗi
        RAISERROR('Invalid username or password.', 16, 1);
    END
END;







CREATE proc UserLogin_2
	@Username NVARCHAR(50),
    @PasswordHash NVARCHAR(255)
as
begin try
	if not exists (
		select	* 
		from	Users 
		where	UserName = @UserName and PWDCOMPARE (@PasswordHash, PasswordHash) = 1
	)
	begin
		raiserror (N'Tên đăng nhập hoặc mật khẩu không chính xác.', 16, 1)
		return
	end

end try
begin catch
	declare @err nvarchar(1000) = ERROR_MESSAGE()
	raiserror (@err, 16, 1)
end catch
GO


-- LẤY THÔNG TIN SÁCH

CREATE PROCEDURE GetBookDetails
    @BookID INT
AS
BEGIN
    SELECT BookID, Title, Author, Description, ISBN, PublishedDate, Price, StockQuantity, IsAvailableForRent, RentPrice, CoverImage
    FROM Books
    WHERE BookID = @BookID;
END;



-- ĐĂNG KÝ NGƯỜI DÙNG MỚI (CUSTOMER)

CREATE PROCEDURE RegisterUser
    @Username NVARCHAR(50),
    @PlainPassword NVARCHAR(255),
    @FullName NVARCHAR(100),
    @Email NVARCHAR(100)
AS
BEGIN
    -- Kiểm tra xem Username đã tồn tại chưa
    IF EXISTS (SELECT 1 FROM Users WHERE Username = @Username)
    BEGIN
        RAISERROR('Username already exists.', 16, 1);
    END
    ELSE
    BEGIN

		-- Mã hóa mật khẩu sử dụng PWDENCRYPT
    DECLARE @EncryptedPassword VARBINARY(128) = PWDENCRYPT(@PlainPassword);

    -- Lưu người dùng vào bảng Users
    INSERT INTO Users (Username, PasswordHash, FullName, Email, Role, CreatedAt)
    VALUES (@Username, @EncryptedPassword, @FullName, @Email, 'customer', GETDATE());
	END;
END;



-- NGƯỜI DÙNG MƯỢN SÁCH SẼ ĐƯỢC ADD VÀO RENTALS DƯỚI TRẠNG THÁI 'PENDING'


CREATE PROCEDURE RequestBookRental
    @UserID INT,
    @BookID INT,
    @RentalDate DATETIME,
    @DueDate DATETIME
AS
BEGIN
    -- Kiểm tra xem người dùng đã có yêu cầu mượn sách này hay chưa
    IF NOT EXISTS (SELECT 1 FROM Rentals WHERE UserID = @UserID AND BookID = @BookID AND Status IN ('pending', 'rented'))
    BEGIN
        -- Thêm yêu cầu mượn sách vào bảng Rentals với trạng thái 'pending'
        INSERT INTO Rentals (UserID, BookID, RentalDate, DueDate, Status)
        VALUES (@UserID, @BookID, @RentalDate, @DueDate, 'pending');
    END
    ELSE
    BEGIN
        RAISERROR('User has already rented this book or has a pending request.', 16, 1);
    END
END;




-- NÚT APPROVE

CREATE PROCEDURE ApproveRentalRequest
    @RentalID INT
AS
BEGIN
    BEGIN
        DECLARE @BookID INT;

        -- Lấy thông tin từ bảng Rentals
        SELECT @BookID = BookID
        FROM Rentals
        WHERE RentalID = @RentalID AND Status = 'pending';

        -- Kiểm tra nếu sách còn đủ số lượng để cho mượn
        IF EXISTS (SELECT 1 FROM Books WHERE BookID = @BookID AND StockQuantity > 0)
        BEGIN
            -- Cập nhật trạng thái thành 'rented' và trừ số lượng trong kho
            UPDATE Rentals
            SET Status = 'rented'
            WHERE RentalID = @RentalID;

            -- Trừ số lượng sách trong kho
            UPDATE Books
            SET StockQuantity = StockQuantity - 1
            WHERE BookID = @BookID;
        END
        ELSE
        BEGIN
            RAISERROR('Insufficient stock for the requested book.', 16, 1);
        END
    END
END;





-- NÚT REJECT

CREATE PROCEDURE RejectRentalRequest
    @RentalID INT,
	@UserID INT,
 --   @AdminUserID INT,
    @RejectionReason NVARCHAR(255)
AS
BEGIN
    ---- Kiểm tra xem admin có quyền từ chối hay không
    --IF EXISTS (SELECT 1 FROM Users WHERE UserID = @AdminUserID AND Role = 'admin')
    --BEGIN
        -- Xóa bản ghi trong bảng Rentals
        DELETE FROM Rentals
        WHERE RentalID = @RentalID AND Status = 'pending';

        -- Gửi thông báo lý do từ chối cho khách hàng (giả sử có hệ thống thông báo)
        INSERT INTO Notifications (UserID, Message) VALUES (@UserID, @RejectionReason);

		
	
		-- Cập nhật số lượng tồn kho
		UPDATE Books
		SET StockQuantity = StockQuantity + 1
		WHERE BookID = (SELECT BookID FROM Rentals WHERE RentalID = @RentalID);
    --END
    --ELSE
    BEGIN
        RAISERROR('Only admins can reject rental requests.', 16, 1);
    END
END;


Drop PROCEDURE RejectRentalRequest






-- NÚT RETURN

CREATE PROCEDURE ReturnBook
    @RentalID INT,
    @AdminUserID INT
AS
BEGIN
    -- Kiểm tra xem admin có quyền xử lý trả sách hay không
    IF EXISTS (SELECT 1 FROM Users WHERE UserID = @AdminUserID AND Role = 'admin')
    BEGIN
        DECLARE @BookID INT;

        -- Lấy thông tin từ bảng Rentals
        SELECT @BookID
        FROM Rentals
        WHERE RentalID = @RentalID AND Status = 'rented';

        -- Cập nhật trạng thái thành 'returned' và ngày trả sách
        UPDATE Rentals
        SET Status = 'returned', ReturnDate = GETDATE()
        WHERE RentalID = @RentalID;

        -- Cộng lại số lượng sách vào kho
        UPDATE Books
        SET StockQuantity = StockQuantity + 1
        WHERE BookID = @BookID;
    END
    ELSE
    BEGIN
        RAISERROR('Only admins can process book returns.', 16, 1);
    END
END;






-- THÊM THÔNG BÁO MỚI

CREATE PROCEDURE AddNotification
    @UserID INT,
    @Message NVARCHAR(255)
AS
BEGIN
    -- Thêm thông báo mới vào bảng Notifications
    INSERT INTO Notifications (UserID, Message)
    VALUES (@UserID, @Message);
END;





-- LẤY THÔNG BÁO CHƯA ĐỌC

CREATE PROCEDURE GetUnreadNotifications
    @UserID INT
AS
BEGIN
    -- Lấy danh sách thông báo chưa đọc cho người dùng
    SELECT NotificationID, Message, CreatedAt
    FROM Notifications
    WHERE UserID = @UserID AND IsRead = 0
    ORDER BY CreatedAt DESC;
END;




-- ĐÁNH DẤU THÔNG BÁO ĐÃ ĐỌC

CREATE PROCEDURE MarkNotificationAsRead
    @NotificationID INT
AS
BEGIN
    -- Cập nhật trạng thái thông báo thành đã đọc
    UPDATE Notifications
    SET IsRead = 1
    WHERE NotificationID = @NotificationID;
END;




-- LẤY TẤT CẢ THÔNG BÁO CỦA NGƯỜI DÙNG

CREATE PROCEDURE GetAllNotifications
    @UserID INT
AS
BEGIN
    -- Lấy tất cả thông báo cho người dùng
    SELECT NotificationID, Message, CreatedAt, IsRead
    FROM Notifications
    WHERE UserID = @UserID
    ORDER BY CreatedAt DESC;
END;




-- TỰ ĐỘNG GỬI THÔNG BÁO KHI TỪ CHỐI YÊU CẦU MƯỢN SÁCH

drop TRIGGER Trigger_RejectRentalNotification
ON Rentals
AFTER DELETE
AS
BEGIN
    DECLARE @UserID INT;
    DECLARE @RejectionReason NVARCHAR(255);
	DECLARE @Message NVARCHAR(500);

    -- Lấy thông tin UserID và lý do từ chối từ bảng Deleted
    SELECT @UserID = deleted.UserID, @RejectionReason = deleted.RejectionReason
    FROM deleted;

     -- Tạo thông báo
    SET @Message = 'Your rental request has been rejected. Reason: ' + ISNULL(@RejectionReason, 'No reason provided.');

    -- Thêm thông báo cho người dùng
    EXEC AddNotification @UserID, @Message;
END;




-- TỰ ĐỘNG GỬI THÔNG BÁO KHI YÊU CẦU TRẢ SÁCH THÀNH CÔNG

CREATE TRIGGER Trigger_ReturnRentalNotification
ON Rentals
AFTER UPDATE
AS
BEGIN
    DECLARE @UserID INT;

    -- Lấy thông tin UserID và BookID từ bản ghi đã cập nhật
    SELECT @UserID = inserted.UserID
    FROM inserted
    WHERE inserted.Status = 'returned';

    -- Thêm thông báo cho người dùng
    EXEC AddNotification @UserID, 'Your book rental has been successfully returned.';
END;



---- THÔNG BÁO KHI YÊU CẦU MƯỢN BỊ TỪ CHỐI

--CREATE TRIGGER NotifyCustomerOnRejection
--ON PendingRentals
--AFTER UPDATE
--AS
--BEGIN
--    DECLARE @UserID INT, @Status NVARCHAR(50), @Reason NVARCHAR(255);

--    -- Lấy thông tin trạng thái và lý do từ chối
--    SELECT @UserID = INSERTED.UserID, @Status = INSERTED.Status, @Reason = INSERTED.Reason
--    FROM INSERTED;

--    -- Nếu trạng thái là 'Rejected', gửi thông báo đến khách hàng
--    IF @Status = 'Rejected'
--    BEGIN
--        -- Giả sử chúng ta có bảng Notifications để lưu thông báo
--        INSERT INTO Notifications (UserID, NotificationMessage)
--        VALUES (@UserID, CONCAT('Your rental request has been rejected. Reason: ', @Reason));
--    END
--END;
Drop TRIGGER NotifyCustomerOnRejection



-- QUÊN MẬT KHẨU

CREATE PROCEDURE ResetUserPassword
@Username NVARCHAR(50),
@NewPassword NVARCHAR(255)
AS
BEGIN
-- Kiểm tra xem Username đã tồn tại chưa
IF NOT EXISTS (SELECT 1 FROM Users WHERE Username = @Username)
BEGIN
RAISERROR('Username does not exist.', 16, 1);
RETURN;
END

-- Mã hóa mật khẩu mới
DECLARE @EncryptedPassword VARBINARY(128) = PWDENCRYPT(@NewPassword);

-- Cập nhật mật khẩu đã mã hóa vào cơ sở dữ liệu
UPDATE Users
SET PasswordHash = @EncryptedPassword
WHERE Username = @Username;
END;



-- THÊM, SỬA, XÓA VER.HẬU

CREATE PROCEDURE [dbo].[AddBookByAdmin]
@Title NVARCHAR(255),
@Author NVARCHAR(255),
@Description NVARCHAR(MAX),
@ISBN NVARCHAR(20),
@PublishedDate DATE,
@Price DECIMAL(18, 2),
@StockQuantity INT,
@IsAvailableForRent BIT,
@RentPrice DECIMAL(18, 2),
@CategoryID INT,
@CoverImage NVARCHAR(255)
AS
BEGIN
-- Kiểm tra xem người dùng có phải là admin không
IF EXISTS (SELECT 1 FROM Users WHERE Role = 'admin')
BEGIN
-- Thêm sách mới
INSERT INTO Books (Title, Author, Description, ISBN, PublishedDate, Price, StockQuantity, IsAvailableForRent, RentPrice, CategoryID, CoverImage)
VALUES (@Title, @Author, @Description, @ISBN, @PublishedDate, @Price, @StockQuantity, @IsAvailableForRent, @RentPrice, @CategoryID, @CoverImage);


-- Trả về ID của sách vừa thêm
SELECT SCOPE_IDENTITY() AS BookID;
END
ELSE
BEGIN
RAISERROR('Only admins can add books.', 16, 1);
END
END;





CREATE PROCEDURE [dbo].[DeleteBookByAdmin]
@BookID INT
AS
BEGIN
-- Kiểm tra xem người dùng có phải là admin không
IF EXISTS (SELECT 1 FROM Users WHERE Role = 'admin')
BEGIN
-- Xóa sách
DELETE FROM Books WHERE BookID = @BookID;
END
ELSE
BEGIN
RAISERROR('Only admins can delete books.', 16, 1);
END
END;





CREATE PROCEDURE [dbo].[UpdateBookByAdmin]
@BookID INT,
@Title NVARCHAR(255),
@Author NVARCHAR(255),
@Description NVARCHAR(MAX),
@Price DECIMAL(18, 2),
@StockQuantity INT,
@IsAvailableForRent BIT,
@RentPrice DECIMAL(18, 2),
@CoverImage NVARCHAR(255)
AS
BEGIN
-- Kiểm tra xem người dùng có phải là admin không
IF EXISTS (SELECT 1 FROM Users WHERE Role = 'admin')
BEGIN
-- Cập nhật thông tin sách
UPDATE Books
SET Title = @Title, Author = @Author, Description = @Description, Price = @Price,
StockQuantity = @StockQuantity, IsAvailableForRent = @IsAvailableForRent,
RentPrice = @RentPrice, CoverImage = @CoverImage, UpdatedAt = GETDATE()
WHERE BookID = @BookID;
END
ELSE
BEGIN
RAISERROR('Only admins can update books.', 16, 1);
END
END;










--Bảng user
INSERT INTO Users (Username, PasswordHash, FullName, Email, Phone, Address, Role)
VALUES
('admin', PWDENCRYPT('password123'), 'Admin', 'admin@example.com', '0123456789', '123 Main St', 'admin'),
('user1', PWDENCRYPT('password123'), 'User 1', 'user1@example.com', '0123456789', '456 Elm St', 'customer'),
('user2', PWDENCRYPT('password123'), 'User 2', 'user2@example.com', '0123456789', '789 Oak St', 'customer');
--('user3', 'password123', 'User 3', 'user3@example.com', '0123456789', '101 Oak St', 'customer');

--Bảng Categories 
INSERT INTO Categories (CategoryName, Description)
VALUES
(N'Sách giáo khoa', N'Sách giáo khoa cho học sinh'),
(N'Sách ngoại văn', N'Sách ngoại văn cho người đọc'),
(N'Sách thiếu nhi', N'Sách thiếu nhi cho trẻ em');

--Book
INSERT INTO Books (Title, Author, Description, ISBN, PublishedDate, Price, StockQuantity, IsAvailableForRent, RentPrice, CategoryID, CoverImage)
VALUES
(N'Sách giáo khoa Toán', N'Nguyễn Văn A', N'Sách giáo khoa Toán cho học sinh lớp 1', '1234567890', '2020-01-01', 100000, 10, 1, 50000, 1, 'toan.jpg'),
(N'Sách ngoại văn Harry Potter', N'J.K. Rowling', N'Sách ngoại văn Harry Potter cho người đọc', '9876543210', '2010-01-01', 200000, 5, 0, 0, 2, 'harrypotter.jpg'),
(N'Sách thiếu nhi Cô bé bán diêm', N'Hans Christian Andersen', N'Sách thiếu nhi Cô bé bán diêm cho trẻ em', '1111111111', '2015-01-01', 50000, 20, 1, 20000, 3, 'cobebandiem.jpg');

--order
INSERT INTO Orders (UserID, TotalAmount, OrderDate, Status, PaymentMethod)
VALUES
(1, 100000, '2022-01-01', 'pending', 'cash'),
(2, 200000, '2022-01-15', 'completed', 'bank transfer'),
(3, 50000, '2022-02-01', 'pending', 'cash');

--order details
INSERT INTO OrderDetails (OrderID, BookID, Quantity, Price)
VALUES
--(1, 2, 1, 200000),

(1, 1, 1, 100000),
(2, 2, 1, 200000),
(3, 3, 2, 100000);

--rentals
INSERT INTO Rentals (UserID, BookID, RentalDate, DueDate, ReturnDate, TotalRentalCost, Status)
VALUES(2, 3, '2022-02-01', '2022-12-01', NULL, 20000, 'rented');
--(1, 1, '2023-01-01', '2023-01-15', NULL, 50000, 'rented'),
--(2, 1, '2023-10-01', '2023-10-15', NULL, 50000, 'rented'),
--(3, 1, '2023-10-01', '2023-10-20', NULL, 50000, 'rented');

(1, 1, '2024-01-01', '2024-01-15', NULL, 50000, 'rented'),
(2, 1, '2024-02-01', '2024-02-15', NULL, 50000, 'rented'),
(1, 3, '2024-10-01', '2024-11-15', NULL, 20000, 'rented'),
(2, 3, '2022-02-01', '2022-02-15', NULL, 20000, 'rented');


--(1, 1, '2022-01-01', '2022-01-15', NULL, 50000, 'rented'),
(1, 3, '2024-10-01', '2024-11-15', NULL, 20000, 'rented'),
--(2, 1, '2022-10-01', '2022-10-15', NULL, 50000, 'rented'),
--(2, 2, '2022-01-15', '2022-02-01', '2022-02-01', 100000, 'returned'),

--(3, 1, '2022-10-01', '2022-10-20', NULL, 50000, 'rented'),
(3, 3, '2022-02-01', '2022-02-15', NULL, 20000, 'rented');

--reviews
INSERT INTO Reviews (BookID, UserID, Rating, Comment)
VALUES
(1, 1, 5, 'Sách rất hay'),
(2, 2, 4, 'Sách khá tốt'),
(3, 3, 3, 'Sách bình thường');

--payment
INSERT INTO Payments (OrderID, PaymentDate, PaymentAmount, PaymentMethod)
VALUES
(1, '2022-01-01', 100000, 'cash'),
(2, '2022-01-15', 200000, 'bank transfer'),
(3, '2022-02-01', 50000, 'cash');

--cart
INSERT INTO Cart (UserID, BookID, Quantity)
VALUES
(1, 1, 1),
(2, 2, 1),
(3, 3, 2);


INSERT INTO BookRequests (UserID, BookID, RequestDate, Status, RejectionReason)
VALUES
(1, 3, '2022-10-20', 'approved', NULL);

select * from Books
select * from Rentals
Select * from OrderDetails

select * from Users

