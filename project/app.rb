require "bcrypt"
require "sinatra"
require "slim"
require "sqlite3"

db = SQLite3::Database.open("db/data.db")
error = ""

get("/") do
    slim(:index, locals:{error: error})
end

post("/login") do
    error = ""
    username = params["username"]
    password = params["password"]
    p username
    p password
    p BCrypt::Password.create(password)
    result = db.execute("SELECT userID FROM users WHERE username=?", username)
    p result
    if result.empty?
        error = "user doesn't exist"
        p "it not be working"
    else
        password_digest = db.execute("SELECT password_digest FROM users WHERE userID=?", result)[0][0]
        if BCrypt::Password.new(password_digest) == password
            error = "login successful!"
        else
            error = "incorrect password"
        end
        
    end

    redirect to ("/")
end