require_relative "model.rb"
require "bcrypt"
require "sinatra"
require "slim"
require "sqlite3"

login_attempts = 0
error = ""
result = ""

get("/") do
    slim(:index, locals:{error: error})
end

post("/login") do
    error = ""
    username = params["username"]
    password = params["password"]

    result = dbselect(:user_id, :users, :username, username)
    
    if result.empty?
        error = "user doesn't exist"
    else
        if password_compare(password, result) == true
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
        user_exist = dbselect(:user_id, :users, :username, username)
        if user_exist.empty?
            dbinsert(:users, [:username, :password_digest], [username, bcrypt(password)])
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
    username = dbselect(:username, :users, :user_id, user_id)[0][0]
    inventory = dbselect([:item_name, :item_id, :item_amount], :inventory, :user_id, user_id)
    progress = dbselect(:story_progress_id, :user_progress, :user_id, user_id)
    
    if progress.empty?
        progress = 1
        dbinsert(:user_progress, [:user_id, :story_progress_id], [user_id, 1])
    end

    current_story = dbselect(:text, :story, :id, progress)
    if current_story.empty?
        progress = 0
        current_story = dbselect(:text, :story, :id, 0)
    end
    current_story = current_story
    choices = dbselect(:text, :choices, :story_id, progress)
    path_id = dbselect(:path_id, :choices, :story_id, progress)
    slim(:start, locals:{username: username, inventory: inventory, current_story: current_story, choices: choices, path_id: path_id})
end

post("/logout")do
    result = ""
    redirect to ("/")
end



post("/rand_item") do
    items = dbselect2([:item_id, :item, :description], :item_list,)
    rand_item = items.sample
    # if db.execute("SELECT item_amount FROM inventory WHERE user_id=? AND item_id=?", [result, rand_item[0]]).empty?
    if dbselect(:item_amount, :inventory, [:user_id, :item_id], [result, rand_item[0]]).empty?
        dbinsert(:inventory, [:item_id, :item_name, :user_id, :item_amount], [rand_item[0], rand_item[1], result, 1])
    else
        item_amount = dbselect(:item_amount, :inventory, [:user_id, :item_id], [result, rand_item[0]])
        db.execute("UPDATE inventory SET item_amount=? WHERE user_id=? AND item_id=?", [item_amount+1, result, rand_item[0]])
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