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



# Lets an already existing user log in.
#
# @param [String] username, entered username
# @param [String] password, entered password
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

# Creates a new user
#
# @param [String] username, entered username
# @param [String] password, entered password
# @param [String] password_confirm, password confirmation (used to make sure the passwords match)
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
    choice_id = dbselect(:choice_id, :choices, :story_id, progress)
    require_item = dbselect([:require_item, :require_amount], :choices, :story_id, progress)
    # p require_item
    # p choices
    slim(:start, locals:{username: username, inventory: inventory, current_story: current_story, choices: choices, choice_id: choice_id, require_item: require_item})
end

post("/logout")do
    result = ""
    redirect to ("/")
end



post("/rand_item") do
    items = dbselect2([:item_id, :item, :description], :item_list,)
    rand_item = items.sample
    if dbselect(:item_amount, :inventory, [:user_id, :item_id], [result, rand_item[0]]).empty?
        dbinsert(:inventory, [:item_id, :item_name, :user_id, :item_amount], [rand_item[0], rand_item[1], result, 1])
    else
        item_amount = dbselect(:item_amount, :inventory, [:user_id, :item_id], [result, rand_item[0]])
        dbupdate(:inventory, :item_amount, [:user_id, :item_id], [item_amount[0][0]+1, result, rand_item[0]])
    end
    redirect to ("/start")
end


post("/delete_item") do
    id = params["deleteme"]
    item_amount = dbselect(:item_amount, :inventory, [:item_id, :user_id], [id, result])
    if item_amount[0][0] == 1
        dbdelete(:inventory, [:item_id, :user_id], [id, result])
    else
        dbupdate(:inventory, :item_amount, [:item_id, :user_id], [item_amount[0][0]-1, id, result])
    end
    redirect to ("/start")
end

post("/update_game") do
    id = params["choice"]
    path_id = dbselect(:path_id, :choices, :choice_id, id)
    give_item = dbselect(:give_item, :choices, :choice_id, id)
    require_item = dbselect(:require_item, :choices, :choice_id, id)
    dbupdate(:user_progress, :story_progress_id, :user_id, [path_id, result])

    if require_item[0][0] != nil
        require_amount = dbselect(:require_amount, :choices, :choice_id, id)
        item_amount = dbselect(:item_amount, :inventory, [:item_id, :user_id], [require_item, result])
        n = item_amount[0][0] - require_amount[0][0]

        if n == 0
            dbdelete(:inventory, [:item_id, :user_id], [require_item, result])
        else
            dbupdate(:inventory, :item_amount, [:item_id, :user_id], [n, require_item, result])
        end
    end

    if give_item[0][0] != nil
        give_amount = dbselect(:give_amount, :choices, :choice_id, id)
        item_amount = dbselect(:item_amount, :inventory, [:item_id, :user_id], [give_item, result])
        
        if item_amount == []
            name = dbselect(:item, :item_list, :item_id, give_item)
            dbinsert(:inventory, [:item_id, :item_name, :user_id, :item_amount], [give_item[0][0], name[0][0], result, give_amount[0][0]])
        else
            n = give_amount[0][0] + item_amount[0][0]
            dbupdate(:inventory, :item_amount, [:item_id, :user_id], [n, give_item, result])
        end
    end
    redirect to ("/start")
end