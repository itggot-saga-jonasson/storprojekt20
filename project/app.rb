require "bcrypt"
require "sinatra"
require "slim"
require "sqlite3"


salt = "stark"
db = SQLite3::Database.open("db/data.db")
error = ""
result = ""

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
    user_id = result
    if user_id.empty?
        error = "Log in first!"
        redirect to ("/")
    end
    username = db.execute("SELECT username FROM users WHERE user_id=?", user_id)[0][0]
    inventory = db.execute("SELECT item_name, item_id FROM inventory WHERE user_id=?", user_id)
    # p inventory
    slim(:start, locals:{username: username, inventory: inventory})
end

post("/logout")do
    result = ""
    redirect to ("/")
end

post("/rand_item") do
    items = db.execute("SELECT item_id, item, description FROM item_list")
    rand_item = items.sample
    db.execute("INSERT INTO inventory(item_id, item_name, user_id) VALUES (?,?,?)",[rand_item[0], rand_item[1], result])
    redirect to ("/start")
end

post("/delete_item") do
    id = params["deleteme"]
    db.execute("DELETE FROM inventory WHERE item_id=? AND user_id=? LIMIT 1", [id, result])

    redirect to ("/start")
end