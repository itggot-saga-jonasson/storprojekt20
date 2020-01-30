require "bcrypt"
require "sinatra"
require "slim"
require "sqlite3"


salt = "stark"
db = SQLite3::Database.open("db/data.db")
error = ""

get("/") do
    slim(:index, locals:{error: error})
end

post("/login") do
    error = ""
    username = params["username"]
    password = params["password"]
    # p username
    # p password
    # p BCrypt::Password.create(password + salt)
    result = db.execute("SELECT user_id FROM users WHERE username=?", username)
    # p result
    if result.empty?
        error = "user doesn't exist"
        # p "it not be working"
    else
        password_digest = db.execute("SELECT password_digest FROM users WHERE user_id=?", result)[0][0]
        if BCrypt::Password.new(password_digest) == password + salt
            redirect to ("/start")
        else
            error = "incorrect password"
        end
        
    end

    redirect to ("/")
end

post("/create_user") do
    error = ""
    username = params["username"]
    password = params["password"]
    password_confirm = params["password_confirm"]
    if password != password_confirm
        error = "Passwords don't match."
    else
        user_exist = db.execute("SELECT user_id FROM users WHERE username=?", username)
        if user_exist.empty?
            password_digest = BCrypt::Password.create(password+salt)
            db.execute("INSERT INTO users(username, password_digest) VALUES (?,?)", [username, password_digest])
            error = "user successfully created!"
        else
            error = "Username taken."
        end

    end

    redirect to ("/")
end

get("/start") do
    # work in progress

    slim(:start)
end