require "bcrypt"
require "sinatra"
require "slim"
require "sqlite3"
require_relative "model.rb"

login_attempts = 0
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

    result = db.execute("SELECT user_id FROM users WHERE username=?", username)
    
    if result.empty?
        error = "user doesn't exist"
    else
        password_digest = db.execute("SELECT password_digest FROM users WHERE user_id=?", result)[0][0]
        if BCrypt::Password.new(password_digest) == password + salt
            redirect to ("/start")
        else
            error = "incorrect password"
            login_attempts += 1
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
    inventory = db.execute("SELECT item_name, item_id, item_amount FROM inventory WHERE user_id=?", user_id)
    progress = db.execute("SELECT story_progress_id FROM user_progress WHERE user_id=?", user_id)
    
    if progress.empty?
        progress = 1
        db.execute("INSERT INTO user_progress(user_id, story_progress_id) VALUES (?,1)", user_id)
    end

    current_story = db.execute("SELECT text FROM story WHERE id=?", progress)
    if current_story.empty?
        progress = 0
        current_story = db.execute("SELECT text FROM story WHERE id=0")
    end
    current_story = current_story

    choices = db.execute("SELECT text FROM choices WHERE story_id=?", progress)
    path_id = db.execute("SELECT path_id FROM choices WHERE story_id=?", progress)
    slim(:start, locals:{username: username, inventory: inventory, current_story: current_story, choices: choices, path_id: path_id})
end

post("/logout")do
    result = ""
    redirect to ("/")
end



post("/rand_item") do
    items = db.execute("SELECT item_id, item, description FROM item_list")
    rand_item = items.sample
    if db.execute("SELECT item_amount FROM inventory WHERE user_id=? AND item_id=?", [result, rand_item[0]]).empty?
        db.execute("INSERT INTO inventory(item_id, item_name, user_id, item_amount) VALUES (?,?,?,1)",[rand_item[0], rand_item[1], result])
    else
        db.execute("UPDATE inventory SET item_amount=item_amount+1 WHERE user_id=? AND item_id=?", [result, rand_item[0]])
    end
    redirect to ("/start")
end


post("/delete_item") do
    id = params["deleteme"]
    item_amount = db.execute("SELECT item_amount FROM inventory WHERE item_id=? AND user_id=?", [id, result])
    if item_amount[0][0] == 1
        db.execute("DELETE FROM inventory WHERE item_id=? AND user_id=?", [id, result])
    else
        db.execute("UPDATE inventory SET item_amount=item_amount-1 WHERE item_id=? AND user_id=?", [id, result])
    end
    redirect to ("/start")
end

post("/update_game") do
    id = params["choice"]
    db.execute("UPDATE user_progress SET story_progress_id=? WHERE user_id=?", [id, result])
    redirect to ("/start")
end