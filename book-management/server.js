//server.js
const express = require("express");
const sql = require("mssql");
const cors = require("cors");
const jwt = require("jsonwebtoken");
// const bcrypt = require("bcrypt");
const nodemailer = require("nodemailer");

const app = express();
const port = 3000;

// Cấu hình CORS
app.use(
  cors({
    origin: ["http://localhost:3000"],
  })
);

app.use(express.json()); // Middleware để phân tích yêu cầu JSON

// Cấu hình kết nối đến SQL Server
const config = {
  server: "sql.bsite.net\\MSSQL2016",
  database: "deadlinengapdau_BookManagement",
  user: "deadlinengapdau_BookManagement",
  password: "123456789",
  options: {
    encrypt: true,
    trustServerCertificate: true,
  },
};

// Khóa bí mật để ký JWT
const JWT_SECRET = "your_secret_key"; // Thay đổi thành một khóa bí mật an toàn

// Create a transporter object using SMTP
const transporter = nodemailer.createTransport({
  host: "smtp.gmail.com", // Replace with your SMTP server
  port: 465, // Replace with your SMTP port
  secure: true, // true for 465, false for other ports
  auth: {
    user: "your-email@example.com", // Replace with your email
    pass: "your-email-password", // Replace with your email password
  },
});

// Middleware để xác thực JWT và kiểm tra vai trò
const authenticateJWT = (req, res, next) => {
  const token = req.headers["authorization"]?.split(" ")[1];

  if (token) {
    jwt.verify(token, JWT_SECRET, (err, user) => {
      if (err) {
        return res.sendStatus(403);
      }
      req.user = user; // Lưu thông tin người dùng vào req.user
      next();
    });
  } else {
    res.sendStatus(401);
  }
};

// API đăng nhập
app.post("/api/login", async (req, res) => {
  const { username, password } = req.body;

  try {
    const pool = await sql.connect(config);
    const result = await pool
      .request()
      .input("Username", sql.NVarChar, username)
      .input("PlainPassword", sql.NVarChar, password)
      .execute("UserLogin"); // Gọi thủ tục UserLogin

    if (result.recordset.length > 0) {
      const user = result.recordset[0];
      const userInfo = await pool
        .request()
        .input("Username", sql.NVarChar, username)
        .query("SELECT * FROM Users WHERE Username = @Username");

      // Lấy vai trò và userID từ thông tin người dùng
      const role = userInfo.recordset[0]?.Role;
      const userID = userInfo.recordset[0]?.UserID;

      // Tạo token JWT
      const token = jwt.sign(
        { username, role, userID },
        JWT_SECRET,
        { expiresIn: "4h" } // Token sẽ hết hạn sau x giờ
      );

      res.status(200).json({
        message: "Login successful",
        token, // Trả về token
        user: { ...user, ...userInfo.recordset[0], role, userID },
      });
    } else {
      res.status(401).json({ message: "Invalid credentials" });
    }
  } catch (err) {
    console.error("Login failed: ", err);
    res.status(500).send("Error during login");
  }
});

// API đăng ký tài khoản
app.post("/api/register", async (req, res) => {
  const { username, password, fullName, email } = req.body;

  // Validate input
  if (!username || !password || !fullName || !email) {
    return res.status(400).json({ message: "All fields are required." });
  }

  // Validate email format (basic regex)
  const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
  if (!emailRegex.test(email)) {
    return res.status(400).json({ message: "Invalid email format." });
  }

  try {
    const pool = await sql.connect(config);
    // Execute stored procedure
    await pool
      .request()
      .input("Username", sql.NVarChar, username)
      .input("PlainPassword", sql.NVarChar, password)
      .input("FullName", sql.NVarChar, fullName)
      .input("Email", sql.NVarChar, email)
      .execute("RegisterUser");

    res.status(201).json({ message: "User registered successfully" });
  } catch (err) {
    if (err.number === 50000) {
      // Custom error number for username exists
      return res.status(400).json({ message: err.message });
    }
    console.error("Registration failed: ", err);
    res.status(500).send("Error during registration");
  }
});

// // API yêu cầu cấp lại mk
// app.post("/api/request-reset-password", async (req, res) => {
//   const { username } = req.body;

//   if (!username) {
//     return res.status(400).json({ message: "Username is required." });
//   }

//   try {
//     const pool = await sql.connect(config);

//     // Tạo token reset mật khẩu
//     const token = jwt.sign({ username }, JWT_SECRET, { expiresIn: "1h" });

//     // Gửi email chứa liên kết reset mật khẩu
//     // await sendResetPasswordEmail(username, token);

//     res
//       .status(200)
//       .json({ message: "Reset password link has been sent to your email." });
//   } catch (err) {
//     console.error("Error requesting reset password: ", err);
//     res.status(500).send("Error requesting reset password");
//   }
// });

//API yêu cầu cấp lại mk qua email (nodemailer)
app.post("/api/request-reset-password", async (req, res) => {
  const { username } = req.body;

  if (!username) {
    return res.status(400).json({ message: "Username is required." });
  }

  try {
    const pool = await sql.connect(config);

    // Retrieve the user's email from the database
    const userResult = await pool
      .request()
      .input("Username", sql.NVarChar, username)
      .query("SELECT Email FROM Users WHERE Username = @Username");

    if (userResult.recordset.length === 0) {
      return res.status(404).json({ message: "User  not found." });
    }

    const userEmail = userResult.recordset[0].Email;

    // Tạo token reset mật khẩu
    const token = jwt.sign({ username }, JWT_SECRET, { expiresIn: "1h" });

    // Tạo link reset mật khẩu
    const resetLink = `http://localhost:3000/reset-password?token=${token}`;

    // Gửi email chứa liên kết reset mật khẩu
    await transporter.sendMail({
      from: '"Book Management" <your-email@example.com>', // sender address
      to: userEmail, // recipient's email
      subject: "Password Reset Request", // Subject line
      text: `You requested a password reset. Click the link to reset your password: ${resetLink}`, // plain text body
      html: `<b>You requested a password reset. Click the link to reset your password:</b> <a href="${resetLink}">${resetLink}</a>`, // html body
    });

    res
      .status(200)
      .json({ message: "Reset password link has been sent to your email." });
  } catch (err) {
    console.error("Error requesting reset password: ", err);
    res.status(500).send("Error requesting reset password");
  }
});

// //API cấp lại mk
// app.post("/api/reset-password", authenticateJWT, async (req, res) => {
//   const { token, newPassword } = req.body;

//   if (!token || !newPassword) {
//     return res.status(400).json({ message: "Token and new password are required." });
//   }

//   try {
//     const decoded = jwt.verify(token, JWT_SECRET);
//     const username = decoded.username;

//     const pool = await sql.connect(config);
//     const hashedPassword = await bcrypt.hash(newPassword, 10);

//     const result = await pool
//       .request()
//       .input("Username", sql.NVarChar, username)
//       .input("NewPassword", sql.NVarChar, hashedPassword)
//       .query(`
//         UPDATE Users
//         SET Password = @NewPassword
//         WHERE Username = @Username
//       `);

//     if (result.rowsAffected[0] > 0) {
//       res.status(200).json({ message: "Password updated successfully." });
//     } else {
//       res.status(404).json({ message: "User not found." });
//     }
//   } catch (err) {
//     console.error("Error resetting password: ", err);
//     res.status(500).send("Error resetting password");
//   }
// });

// API cấp lại mk
// app.put("/api/reset-password", authenticateJWT, async (req, res) => {
//   console.log("Request Body:", req.body);
//   const { username, newPassword } = req.body;

//   if (!username || !newPassword) {
//     return res
//       .status(400)
//       .json({ message: "Username and new password are required." });
//   }

//   try {
//     const pool = await sql.connect(config);

//     const result = await pool
//       .request()
//       .input("Username", sql.NVarChar, username)
//       .input("NewPassword", sql.NVarChar, newPassword)
//       .execute("ResetUserPassword");

//     if (result.rowsAffected[0] > 0) {
//       res.status(200).json({ message: "Password updated successfully." });
//     } else {
//       res.status(404).json({ message: "User not found." });
//     }
//   } catch (err) {
//     console.error("Error resetting password: ", err);
//     res.status(500).send("Error resetting password");
//   }
// });

// API để lấy tất cả người dùng (chỉ cho admin)
app.get("/api/users", authenticateJWT, async (req, res) => {
  if (req.user.role !== "admin") {
    return res.status(403).json({ message: "Access denied" });
  }

  try {
    const pool = await sql.connect(config);
    const result = await pool.request().query("SELECT * FROM Users");
    res.json(result.recordset);
  } catch (err) {
    console.error("Query failed: ", err);
    res.status(500).send("Error retrieving data");
  }
});

// API để lấy thông tin người dùng theo username
app.get("/api/users/:username", authenticateJWT, async (req, res) => {
  const username = req.params.username;

  try {
    const pool = await sql.connect(config);
    const result = await pool
      .request()
      .input("Username", sql.NVarChar, username)
      .query("SELECT * FROM Users WHERE Username = @Username");

    if (result.recordset.length > 0) {
      res.status(200).json(result.recordset[0]);
    } else {
      res.status(404).json({ message: "User not found" });
    }
  } catch (err) {
    console.error("Query failed: ", err);
    res.status(500).send("Error retrieving user data");
  }
});

// API để lấy thông tin người dùng theo username (chỉ cho admin)
app.get("/api/users/:username", authenticateJWT, async (req, res) => {
  if (req.user.role !== "admin") {
    return res.status(403).json({ message: "Access denied" });
  }

  const username = req.params.username;

  try {
    const pool = await sql.connect(config);
    const result = await pool
      .request()
      .input("Username", sql.NVarChar, username)
      .query("SELECT * FROM Users WHERE Username = @Username");

    if (result.recordset.length > 0) {
      res.status(200).json(result.recordset[0]);
    } else {
      res.status(404).json({ message: "User not found" });
    }
  } catch (err) {
    console.error("Query failed: ", err);
    res.status(500).send("Error retrieving user data");
  }
});

// API để cập nhật thông tin người dùng theo username
app.put("/api/users/:username", authenticateJWT, async (req, res) => {
  const { username } = req.params;
  const { fullName, email, phoneNumber, address } = req.body;

  try {
    const pool = await sql.connect(config);
    const result = await pool
      .request()
      .input("Username", sql.NVarChar, username)
      .input("FullName", sql.NVarChar, fullName)
      .input("Email", sql.NVarChar, email)
      .input("Phone", sql.NVarChar, phoneNumber)
      .input("Address", sql.NVarChar, address).query(`
                UPDATE Users 
                SET FullName = @FullName, 
                    Email = @Email, 
                    Phone = @Phone, 
                    Address = @Address
                WHERE Username = @Username
            `);

    if (result.rowsAffected[0] > 0) {
      res.status(200).json({ message: "User updated successfully" });
    } else {
      res.status(404).json({ message: "User not found" });
    }
  } catch (err) {
    console.error("Update failed: ", err);
    res.status(500).send("Error updating user data");
  }
});

// API để cập nhật thông tin người dùng theo username (chỉ cho admin)
app.put("/api/users/:username", authenticateJWT, async (req, res) => {
  if (req.user.role !== "admin") {
    return res.status(403).json({ message: "Access denied" });
  }

  const { username } = req.params;
  const { fullName, email, phoneNumber, address } = req.body;

  try {
    const pool = await sql.connect(config);
    const result = await pool
      .request()
      .input("Username", sql.NVarChar, username)
      .input("FullName", sql.NVarChar, fullName)
      .input("Email", sql.NVarChar, email)
      .input("Phone", sql.NVarChar, phoneNumber)
      .input("Address", sql.NVarChar, address).query(`
                UPDATE Users 
                SET FullName = @FullName, 
                    Email = @Email, 
                    Phone = @Phone, 
                    Address = @Address
                WHERE Username = @Username
            `);

    if (result.rowsAffected[0] > 0) {
      res.status(200).json({ message: "User updated successfully" });
    } else {
      res.status(404).json({ message: "User not found" });
    }
  } catch (err) {
    console.error("Update failed: ", err);
    res.status(500).send("Error updating user data");
  }
});

// API để xóa người dùng (chỉ cho admin)
app.delete("/api/users/:username", authenticateJWT, async (req, res) => {
  if (req.user.role !== "admin") {
    return res.status(403).json({ message: "Access denied" });
  }

  const username = req.params.username;

  try {
    const pool = await sql.connect(config);
    const result = await pool
      .request()
      .input("Username", sql.NVarChar, username)
      .query("DELETE FROM Users WHERE Username = @Username");

    if (result.rowsAffected[0] > 0) {
      res.status(200).json({ message: "User deleted successfully" });
    } else {
      res.status(404).json({ message: "User not found" });
    }
  } catch (err) {
    console.error("Delete failed: ", err);
    res.status(500).send("Error deleting user data");
  }
});

// API để lấy danh sách sách
app.get("/api/books", authenticateJWT, async (req, res) => {
  try {
    const pool = await sql.connect(config);
    const result = await pool.request().query("SELECT * FROM Books"); // Lấy các trường cần thiết
    res.status(200).json(result.recordset);
  } catch (err) {
    console.error("Error fetching books: ", err);
    res.status(500).send("Error retrieving books");
  }
});

// API để lấy thông tin chi tiết sách theo ID
app.get("/api/books/:id", authenticateJWT, async (req, res) => {
  if (req.user.role !== "admin") {
    return res.status(403).json({ message: "Access denied" });
  }

  const bookId = req.params.id;

  try {
    const pool = await sql.connect(config);
    const result = await pool
      .request()
      .input("BookID", sql.NVarChar, bookId)
      .query("SELECT * FROM Books WHERE BookID = @BookID");

    if (result.recordset.length > 0) {
      res.status(200).json(result.recordset[0]);
    } else {
      res.status(404).json({ message: "Book not found" });
    }
  } catch (err) {
    console.error("Error fetching book details: ", err);
    res.status(500).send("Error retrieving book data");
  }
});

// Middleware to check user authentication and role
// const checkAdmin = (req, res, next) => {
//   console.log("User:", req.user); // Ghi lại thông tin người dùng
//   console.log("User Role:", req.user?.role); // Ghi lại vai trò người dùng

//   const userRole = req.user?.role;
//   if (userRole === "admin") {
//     return next();
//   }
//   return res.status(403).json({ message: "Access denied" });
// };

// API thêm sách (chỉ cho admin)
// app.post("/api/books/add", authenticateJWT, async (req, res) => {
//   if (req.user.role !== "admin") {
//     return res.status(403).json({ message: "Access denied" });
//   }

//   const {
//     title,
//     author,
//     coverImage,
//     stockQuantity,
//     description,
//     isbn,
//     publishedDate,
//     price,
//     isAvailableForRent,
//     rentPrice,
//     categoryId,
//   } = req.body;

//   // Kiểm tra dữ liệu đầu vào
//   if (!title || !author || !isbn) {
//     return res.status(400).json({ message: "Missing required fields" });
//   }

//   try {
//     const pool = await sql.connect(config);
//     const result = await pool
//       .request()
//       // .input("AdminUserID", sql.Int, req.user.id)
//       .input("Title", sql.NVarChar, title)
//       .input("Author", sql.NVarChar, author)
//       .input("Description", sql.NVarChar, description)
//       .input("ISBN", sql.NVarChar, isbn)
//       .input("PublishedDate", sql.Date, publishedDate)
//       .input("Price", sql.Decimal(18, 2), price)
//       .input("StockQuantity", sql.Int, stockQuantity)
//       .input("IsAvailableForRent", sql.Bit, isAvailableForRent)
//       .input("RentPrice", sql.Decimal(18, 2), rentPrice)
//       .input("CategoryID", sql.Int, categoryId)
//       .input("CoverImage", sql.NVarChar, coverImage)
//       .execute("AddBookByAdmin");

//     res
//       .status(201)
//       .json({
//         message: "Book added successfully",
//         bookId: result.recordset[0].BookID,
//       });
//   } catch (err) {
//     console.error("Error adding book: ", err);
//     res.status(500).send("Error adding book");
//   }
// });

app.post("/api/books/add", authenticateJWT, async (req, res) => {
  if (req.user.role !== "admin") {
    return res.status(403).json({ message: "Access denied" });
  }

  // Kiểm tra xem req.body là một mảng hay một đối tượng
  const books = Array.isArray(req.body) ? req.body : [req.body]; // Nếu không phải là mảng, biến thành mảng

  // Kiểm tra dữ liệu đầu vào
  if (!books.length) {
    return res.status(400).json({ message: "Missing required fields" });
  }

  const addedBooks = [];
  const errors = [];

  try {
    const pool = await sql.connect(config);

    for (const book of books) {
      const {
        title,
        author,
        coverImage,
        stockQuantity,
        description,
        isbn,
        publishedDate,
        price,
        isAvailableForRent,
        rentPrice,
        categoryId,
      } = book;

      // Kiểm tra từng trường bắt buộc
      if (
        !title ||
        !author ||
        !isbn ||
        !publishedDate ||
        price == null ||
        stockQuantity == null
      ) {
        errors.push({ isbn, message: "Missing required fields" });
        continue; // Bỏ qua sách này và tiếp tục với sách tiếp theo
      }

      // Kiểm tra các trường số
      if (
        price < 0 ||
        stockQuantity < 0 ||
        (isAvailableForRent && rentPrice < 0)
      ) {
        errors.push({
          isbn,
          message: "Invalid values for price or stock quantity",
        });
        continue; // Bỏ qua sách này và tiếp tục với sách tiếp theo
      }

      const result = await pool
        .request()
        .input("Title", sql.NVarChar, title)
        .input("Author", sql.NVarChar, author)
        .input("Description", sql.NVarChar, description)
        .input("ISBN", sql.NVarChar, isbn)
        .input("PublishedDate", sql.Date, publishedDate)
        .input("Price", sql.Decimal(18, 2), price)
        .input("StockQuantity", sql.Int, stockQuantity)
        .input("IsAvailableForRent", sql.Bit, isAvailableForRent)
        .input("RentPrice", sql.Decimal(18, 2), rentPrice)
        .input("CategoryID", sql.Int, categoryId)
        .input("CoverImage", sql.NVarChar, coverImage)
        .execute("AddBookByAdmin");

      addedBooks.push({ bookId: result.recordset[0].BookID, isbn });
    }

    if (errors.length > 0) {
      return res
        .status(400)
        .json({ message: "Some books could not be added", errors });
    }

    res.status(201).json({
      message: "Books added successfully",
      addedBooks,
    });
  } catch (err) {
    console.error("Error adding books: ", err);
    res.status(500).send("Error adding books");
  }
});

// API sửa sách (chỉ cho admin)
app.put("/api/books/:id", authenticateJWT, async (req, res) => {
  if (req.user.role !== "admin") {
    return res.status(403).json({ message: "Access denied" });
  }

  const bookId = req.params.id;
  const {
    title,
    author,
    coverImage,
    description,
    price,
    stockQuantity,
    isAvailableForRent,
    rentPrice,
  } = req.body;

  try {
    const pool = await sql.connect(config);
    await pool
      .request()
      .input("BookID", sql.Int, bookId)
      .input("Title", sql.NVarChar, title)
      .input("Author", sql.NVarChar, author)
      .input("Description", sql.NVarChar, description)
      .input("Price", sql.Decimal(18, 2), price)
      .input("StockQuantity", sql.Int, stockQuantity)
      .input("IsAvailableForRent", sql.Bit, isAvailableForRent)
      .input("RentPrice", sql.Decimal(18, 2), rentPrice)
      .input("CoverImage", sql.NVarChar, coverImage)
      .execute("UpdateBookByAdmin");

    res.status(200).json({ message: "Book updated successfully" });
  } catch (err) {
    console.error("Error updating book: ", err);
    res.status(500).send("Error updating book");
  }
});

// API xóa sách (chỉ cho admin)
app.delete("/api/books/:id", authenticateJWT, async (req, res) => {
  if (req.user.role !== "admin") {
    return res.status(403).json({ message: "Access denied" });
  }

  const bookId = req.params.id;

  try {
    const pool = await sql.connect(config);
    await pool
      .request()
      .input("BookID", sql.Int, bookId)
      .execute("DeleteBookByAdmin");

    res.status(200).json({ message: "Book deleted successfully" });
  } catch (err) {
    console.error("Error deleting book: ", err);
    res.status(500).send("Error deleting book");
  }
});

// API yêu cầu mượn sách
app.post("/api/book-requests", authenticateJWT, async (req, res) => {
  const { bookId, rentalDate, dueDate } = req.body;

  // Kiểm tra thông tin đầu vào
  if (!bookId || !rentalDate || !dueDate) {
    return res
      .status(400)
      .json({ message: "Book ID, rental date, and return date are required." });
  }

  try {
    const pool = await sql.connect(config);
    await pool
      .request()
      .input("UserID", sql.Int, req.user.userID)
      .input("BookID", sql.Int, bookId)
      .input("RentalDate", sql.Date, rentalDate)
      .input("DueDate", sql.Date, dueDate)
      .execute("RequestBookRental"); // Gọi thủ tục lưu trữ để xử lý yêu cầu

    res.status(201).json({ message: "Book request submitted successfully." });
  } catch (err) {
    console.error("Error requesting book rental: ", err);
    res.status(500).send("Error requesting book rental");
  }
});

// Lấy danh sách rentals chờ duyệt
app.get("/api/pending", authenticateJWT, async (req, res) => {
  if (req.user.role !== "admin") {
    return res.status(403).json({ message: "Access denied" });
  }

  try {
    // Kết nối đến cơ sở dữ liệu
    const pool = await sql.connect(config);

    const query = `
          SELECT r.*, b.Title, b.Author, b.Description, b.ISBN, b.CoverImage
          FROM Rentals r
          JOIN Books b ON r.BookID = b.BookID
          WHERE r.Status = 'pending'
      `;

    const result = await pool.request().query(query);

    if (result.recordset.length === 0) {
      return res
        .status(404)
        .json({ message: "No rentals found in pending status." });
    }

    return res.status(200).json({ data: result.recordset });
  } catch (error) {
    console.error("Error fetching pending rentals:", error);
    return res.status(400).json({ message: error.message });
  }
});

//Duyệt mượn sách
app.post("/api/approve/:requestId", authenticateJWT, async (req, res) => {
  // Kiểm tra quyền admin
  if (req.user.role !== "admin") {
    return res.status(403).json({ message: "Access denied" });
  }

  const { requestId } = req.params;

  console.log("rental id", requestId);
  try {
    const pool = await sql.connect(config);

    // Gọi stored procedure để phê duyệt yêu cầu mượn
    const result = await pool
      .request()
      .input("RentalID", sql.Int, requestId) // Thay đổi tên tham số cho đúng với stored procedure
      // .input("AdminUserID", sql.Int, req.user.userID) // Nếu cần sử dụng AdminUserID, thêm vào đây
      .execute("ApproveRentalRequest"); // Gọi stored procedure

    // Kiểm tra kết quả
    if (result.rowsAffected[0] === 0) {
      return res
        .status(404)
        .json({ message: "Rental request not found or already processed." });
    }

    res.status(200).json({ message: "Rental request processed successfully." });
  } catch (err) {
    console.error("Error processing rental request: ", err);
    res.status(500).send("Error processing rental request");
  }
});

// API từ chối yêu cầu mượn
app.post(
  "/api/rentals/reject/:requestId",
  authenticateJWT,
  async (req, res) => {
    // Kiểm tra quyền truy cập
    if (req.user.role !== "admin") {
      return res.status(403).json({ message: "Access denied" });
    }

    const { requestId } = req.params;
    const { rejectionReason } = req.body;

    // Kiểm tra lý do từ chối
    if (!rejectionReason) {
      return res.status(400).json({ message: "Rejection reason is required." });
    }

    console.log("RentalID:", requestId);
    console.log("UserID:", req.user.userID);
    console.log("RejectionReason:", rejectionReason);

    try {
      const pool = await sql.connect(config);
      await pool
        .request()
        .input("RentalID", sql.Int, requestId) // ID yêu cầu mượn
        .input("UserID", sql.Int, req.user.userID) // ID người dùng từ token
        .input("RejectionReason", sql.NVarChar, rejectionReason) // Lý do từ chối
        .execute("RejectRentalRequest"); // Gọi stored procedure

      return res
        .status(200)
        .json({ message: "Rental request rejected successfully." });
    } catch (err) {
      console.error("Error rejecting rental request: ", err);
      return res
        .status(500)
        .json({ message: "Error rejecting rental request" });
    }
  }
);

// API trả sách
app.put("/api/rentals/return/:rentalId", authenticateJWT, async (req, res) => {
  const rentalId = req.params.rentalId;
console.log(rentalId);

  try {
    const pool = await sql.connect(config);

    // Kiểm tra xem RentalID có tồn tại và thuộc về UserID hiện tại không
    const checkRental = await pool
      .request()
      .input("RentalID", sql.Int, rentalId)
      .input("UserID", sql.Int, req.user.userID)
      .query(
        "SELECT COUNT(*) AS Count FROM Rentals WHERE RentalID = @RentalID AND UserID = @UserID AND Status = 'rented'"
      );

    if (checkRental.recordset[0].Count === 0) {
      return res
        .status(404)
        .json({ message: "No rental found for this RentalID." });
    }

    // Gọi thủ tục lưu trữ để cập nhật trạng thái
    const result = await pool
      .request()
      .input("RentalID", sql.Int, rentalId)
      .execute("ReturnRental"); // Gọi stored procedure để xử lý việc trả sách

    if (result.rowsAffected[0] > 0) {
      return res.status(200).json({ message: "Book returned successfully." });
    } else {
      return res
        .status(404)
        .json({ message: "No rental found for this book." });
    }
  } catch (err) {
    console.error("Error returning book: ", err);
    return res
      .status(500)
      .json({ message: "Error returning book: " + err.message });
  }
});

// // API để trả sách
// app.put("/api/return-book/:bookId", authenticateJWT, async (req, res) => {
//   const bookId = req.params.bookId;

//   try {
//     const pool = await sql.connect(config);
//     await pool.request().input("BookID", sql.Int, bookId).query(`
//           UPDATE Rentals
//           SET Status = 'returned', ReturnDate = GETDATE()
//           WHERE BookID = @BookID AND Status = 'rented'
//         `);

//     res.status(200).json({ message: "Book returned successfully" });
//   } catch (err) {
//     console.error("Error returning book: ", err);
//     res.status(500).send("Error returning book");
//   }
// });

// // API cập nhật số lượng sách sau khi mượn
// app.put("/api/rentals/borrow/:bookId", authenticateJWT, async (req, res) => {
//   const bookId = req.params.bookId;

//   try {
//     const pool = await sql.connect(config);
//     const result = await pool
//       .request()
//       .input("BookID", sql.Int, bookId)
//       .execute("UpdateBookStockAfterNewRentals"); // Call stored procedure to update stock

//     if (result.rowsAffected[0] > 0) {
//       res
//         .status(200)
//         .json({ message: "Stock updated successfully after borrowing." });
//     } else {
//       res
//         .status(404)
//         .json({ message: "Book not found or insufficient stock." });
//     }
//   } catch (err) {
//     console.error("Error updating stock after borrowing: ", err);
//     res.status(500).send("Error updating stock after borrowing");
//   }
// });

// // API auto cập nhật số lượng sách sau khi mượn
// app.post("/api/rentals/borrow", authenticateJWT, async (req, res) => {
//   const { bookId, dueDate } = req.body;

//   if (!bookId || !dueDate) {
//     return res
//       .status(400)
//       .json({ message: "Book ID and due date are required." });
//   }

//   try {
//     const pool = await sql.connect(config);

//     // Start a transaction
//     const transaction = new sql.Transaction(pool);
//     await transaction.begin();

//     // Update stock quantity
//     const stockUpdateResult = await transaction
//       .request()
//       .input("BookID", sql.Int, bookId)
//       .execute("UpdateBookStockAfterNewRentals");

//     if (stockUpdateResult.rowsAffected[0] === 0) {
//       await transaction.rollback();
//       return res
//         .status(400)
//         .json({ message: "Insufficient stock or book not found." });
//     }

//     // Insert rental record
//     await transaction
//       .request()
//       .input("UserID", sql.Int, req.user.userID)
//       .input("BookID", sql.Int, bookId)
//       .input("DueDate", sql.DateTime, dueDate)
//       .execute("RequestBook");

//     await transaction.commit();
//     res.status(201).json({ message: "Book borrowed successfully." });
//   } catch (err) {
//     console.error("Error borrowing book: ", err);
//     await transaction.rollback();
//     res.status(500).send("Error borrowing book");
//   }
// });

// // API to borrow a book and update stock automatically using trigger
// app.post("/api/rentals/borrow", authenticateJWT, async (req, res) => {
//   const { bookId, dueDate } = req.body;

//   if (!bookId || !dueDate) {
//     return res
//       .status(400)
//       .json({ message: "Book ID and due date are required." });
//   }

//   try {
//     const pool = await sql.connect(config);

//     // Start a transaction
//     const transaction = new sql.Transaction(pool);
//     await transaction.begin();

//     // Insert rental record
//     const result = await transaction
//       .request()
//       .input("UserID", sql.Int, req.user.userID)
//       .input("BookID", sql.Int, bookId)
//       .input("DueDate", sql.DateTime, dueDate)
//       .execute("RequestBook"); // Stored procedure to insert rental record

//     // Commit the transaction
//     await transaction.commit();
//     res.status(201).json({ message: "Book borrowed successfully." });
//   } catch (err) {
//     console.error("Error borrowing book: ", err);
//     await transaction.rollback();
//     res.status(500).send("Error borrowing book");
//   }
// });

// // API cập nhật số lượng sách sau khi trả
// app.put("/api/rentals/return/:bookId", authenticateJWT, async (req, res) => {
//   const bookId = req.params.bookId;

//   try {
//     const pool = await sql.connect(config);
//     const result = await pool
//       .request()
//       .input("BookID", sql.Int, bookId)
//       .execute("UpdateBookStockAfterReturn"); // Call stored procedure to update stock

//     if (result.rowsAffected[0] > 0) {
//       res
//         .status(200)
//         .json({ message: "Stock updated successfully after returning." });
//     } else {
//       res.status(404).json({ message: "Book not found." });
//     }
//   } catch (err) {
//     console.error("Error updating stock after returning: ", err);
//     res.status(500).send("Error updating stock after returning");
//   }
// });

// // API aotu cập nhật số lượng sách sau khi trả
// app.put("/api/rentals/return", authenticateJWT, async (req, res) => {
//   const { bookId } = req.body;

//   if (!bookId) {
//     return res.status(400).json({ message: "Book ID is required." });
//   }

//   try {
//     const pool = await sql.connect(config);

//     // Start a transaction
//     const transaction = new sql.Transaction(pool);
//     await transaction.begin();

//     // Update stock quantity
//     const stockUpdateResult = await transaction
//       .request()
//       .input("BookID", sql.Int, bookId)
//       .execute("UpdateBookStockAfterReturn");

//     if (stockUpdateResult.rowsAffected[0] === 0) {
//       await transaction.rollback();
//       return res.status(404).json({ message: "Book not found." });
//     }

//     // Update rental record to mark as returned
//     await transaction
//       .request()
//       .input("BookID", sql.Int, bookId)
//       .execute("MarkRentalAsReturned"); // Stored procedure to mark rental as returned

//     await transaction.commit();
//     res.status(200).json({ message: "Book returned successfully." });
//   } catch (err) {
//     console.error("Error returning book: ", err);
//     await transaction.rollback();
//     res.status(500).send("Error returning book");
//   }
// });

// API để lấy danh sách sách mà người dùng đang mượn
app.get("/api/borrowed-books/:userId", authenticateJWT, async (req, res) => {
  const userId = req.params.userId;

  try {
    const pool = await sql.connect(config);
    const result = await pool.request().input("UserID", sql.Int, userId).query(`
                SELECT r.RentalID, b.BookID, b.Title, b.Author, b.CoverImage, r.RentalDate, r.DueDate, r.Status
                FROM Rentals r
                JOIN Books b ON r.BookID = b.BookID
                WHERE r.UserID = @UserID AND r.Status = 'rented'
            `); // Lấy thông tin sách mà người dùng đang mượn

    res.status(200).json(result.recordset); // Always return 200, even if empty
  } catch (err) {
    console.error("Error fetching borrowed books: ", err);
    res.status(500).send("Error retrieving borrowed books");
  }
});

// API để lấy danh sách sách mà người dùng đã trả
app.get("/api/returned-books/:userId", authenticateJWT, async (req, res) => {
  const userId = req.params.userId;

  try {
    const pool = await sql.connect(config);
    const result = await pool.request().input("UserID", sql.Int, userId).query(`
                SELECT b.BookID, b.Title, b.Author, b.CoverImage, r.RentalDate, r.ReturnDate. r.Status
                FROM Rentals r
                JOIN Books b ON r.BookID = b.BookID
                WHERE r.UserID = @UserID AND r.Status = 'returned'
            `); // Lấy thông tin sách mà người dùng đã trả

    res.status(200).json(result.recordset); // Always return 200, even if empty
  } catch (err) {
    console.error("Error fetching returned books: ", err);
    res.status(500).send("Error retrieving returned books");
  }
});

// API để lấy danh sách sách mà người dùng đã trả
app.get("/api/returned-books/:userId", authenticateJWT, async (req, res) => {
  const userId = req.params.userId;

  try {
    const pool = await sql.connect(config);
    const result = await pool.request().input("UserID", sql.Int, userId).query(`
                SELECT b.BookID, b.Title, b.Author, b.CoverImage, r.RentalDate, r.ReturnDate
                FROM Rentals r
                JOIN Books b ON r.BookID = b.BookID
                WHERE r.UserID = @UserID AND r.Status = 'returned'
            `); // Lấy thông tin sách mà người dùng đã trả

    if (result.recordset.length > 0) {
      res.status(200).json(result.recordset);
    } else {
      res
        .status(404)
        .json({ message: "No returned books found for this user." });
    }
  } catch (err) {
    console.error("Error fetching returned books: ", err);
    res.status(500).send("Error retrieving returned books");
  }
});

// Bắt đầu lắng nghe các yêu cầu
sql
  .connect(config)
  .then((pool) => {
    console.log("Connected to SQL Server");

    // Bắt đầu lắng nghe các yêu cầu
    app.listen(port, () => {
      console.log(`Server is running on http://localhost:${port}`);
    });
  })
  .catch((err) => {
    console.error("Database connection failed: ", err);
  });
