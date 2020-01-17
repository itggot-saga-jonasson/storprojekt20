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
    result = db.execute("SELECT user_id FROM users WHERE username=?", username)
    p result
    if result.empty?
        error = "user doesn't exist"
        p "it not be working"
    else
        if db.execute("SELECT password_digest FROM users WHERE user_id=?", result) == password
            error = "login successful!"
        else
            error = "incorrect assword"
        end
        # login = db.execute("SELECT user_id FROM users WHERE password_digest=?", password)
        # if login.empty?
        #     error = "Password doesn't match username."
        #     p "it be working"
        # else
        #     error = "login successful!"
        #     p "it be working2"
        # end
    end

    redirect to ("/")
end