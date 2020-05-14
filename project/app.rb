require_relative "model.rb"
require "bcrypt"
require "sinatra"
require "slim"
require "sqlite3"

login_attempts = 0
error = ""
error_message = ""
user_edit_message = ""
result = ""

# Checks that there is a user logged in before doing any requests (is called at the start of every route that requires a user)
def loggedin(id)
    if id.empty?
        redirect to ("/")
    end
end


# Start page.
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

# Creates a new user.
#
# @param [String] username, entered username
# @param [String] password, entered password
# @param [String] password_confirm, password confirmation (used to make sure the passwords match)
post("/user/new") do
    error = ""
    username = params["username"]
    password = params["password"]
    password_confirm = params["password_confirm"]

    if password != password_confirm
        error = "Passwords don't match."
    elsif password.length < 6 or (password =~ /\d/).nil?
        error = "Password must be at least six characters long and contain a number."
    else 
        if username.include? " "
            error = "Username cannot include spaces."
        else
            user_exist = dbselect(:user_id, :users, :username, username)
            if user_exist.empty?
                dbinsert(:users, [:username, :password_digest, :admin], [username, bcrypt(password), 0])
                error = "user successfully created!"
            else
                error = "Username taken."
            end
        end
    end
    redirect to ("/")
end

# Logged in page. 
get("/start") do
    user_edit_message = ""
    loggedin(result)
    user_id = result
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

    users = dbselect2([:user_id, :username], :users)
    items = dbselect2([:item_id, :item], :item_list)
    admin = dbselect(:admin, :users, :user_id, result)[0][0]
    user_id = user_id[0][0]

    slim(:start, locals:{username: username, user_id: user_id, users: users, inventory: inventory, current_story: current_story, choices: choices, choice_id: choice_id, require_item: require_item, items: items, admin: admin})
end


# Logs out the current user.
post("/logout")do
    result = ""
    redirect to ("/")
end


# Gives user a random item.
post("/rand_item") do
    loggedin(result)
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

# Updates inventory
# @param [Integer] id, ID of the item added
# @param [Integer] amount, number of items to add
# @param [Integer] user_id, ID of the user recieving the items 
post("/inventory/update") do
    loggedin(result)
    item_id = params["id"].to_i
    add_amount = params["amount"].to_i
    user_id = params["user_id"].to_i

    if result[0][0] == user_id
        item = dbselect([:item_id, :item, :description], :item_list, :item_id, item_id)
        if item.empty? 
            redirect to ("/start")
        else
            item = item[0]

            if item.empty? == false
                if dbselect(:item_amount, :inventory, [:user_id, :item_id], [result, item[0]]).empty?
                    dbinsert(:inventory, [:item_id, :item_name, :user_id, :item_amount], [item[0], item[1], result, add_amount])
                else
                    item_amount = dbselect(:item_amount, :inventory, [:user_id, :item_id], [result, item[0]])
                    dbupdate(:inventory, :item_amount, [:user_id, :item_id], [item_amount[0][0]+add_amount, result, item[0]])
                end
            end
        end
    else
        error_message = "You don't have the authority to make that decision. What are you doing?"
        redirect to ("/error")
    end


    redirect to ("/start")
end

# Deletes a chosen item from the user's inventory
# @param [Integer] deleteme, the ID of the item
# @param [Integer] user_id, the ID of the user
post("/inventory/delete") do
    loggedin(result)
    id = params["deleteme"]
    user_id = params["user_id"].to_i

    if result[0][0] == user_id
        item_amount = dbselect(:item_amount, :inventory, [:item_id, :user_id], [id, result])
        if item_amount[0][0] == 1
            dbdelete(:inventory, [:item_id, :user_id], [id, result])
        else
            dbupdate(:inventory, :item_amount, [:item_id, :user_id], [item_amount[0][0]-1, id, result])
        end
        redirect to ("/start")
    else
        error_message = "You don't seem to match the user making that request. What do you think you're doing?"
        redirect to ("/error")
    end
end

# Deletes a select user
# @param [Integer] deleteuser, The ID of the select user
# @param [Integer] user_id, the ID of the user deleting the user
post("/users/delete") do
    loggedin(result)
    id = params["deleteuser"].to_i
    user_id = params["user_id"].to_i
    admin = dbselect(:admin, :users, :user_id, user_id)[0][0]

    if result[0][0] == user_id
        if user_id == id or admin == 1
            dbdelete(:users, :user_id, id)
            dbdelete(:inventory, :user_id, id)

            if user_id == id
                result = ""
                error = "User successfully deleted."
                redirect to ("/")
            else
                redirect to ("/start")
            end
        end
    end
    error_message = "You don't have the authority to make that decision. What are you doing?"
    redirect to ("/error")
end

# Page where a user can edit their user
# @param [Integer] :id, the user's ID
get("/users/:id/edit") do
    loggedin(result)
    id = params[:id].to_i
    user_id = result[0][0].to_i

    if id != user_id
        error_message = "You're not allowed to access that. What are you doing?"
        redirect to ("/error")
    end
    username = dbselect(:username, :users, :user_id, result)[0][0]
        user_id = result[0][0]
        # p user_id

        slim(:"users/edit", locals:{username: username, user_id: id, user_edit_message: user_edit_message})
    
end

# Updates a user's name
# @param [String] name, new name
# @param [Integer] user_id, the ID of the user
get '/users/:id/username/edit' do
    loggedin(result)
    name = params["user"]
    user_id = params["user_id"].to_i

    if result[0][0] == user_id
        user_exist = dbselect(:user_id, :users, :username, username)
        if user_exist.empty?
            dbupdate(:users, :username, :user_id, [name, user_id])
            user_edit_message = "Username successfully changed!"

            redirect back
        else
            user_edit_message = "username taken!"
        end
    end
    error_message = "You don't have the authority to make that decision. What are you doing?"
    redirect to ("/error")
  end

# Updates a user's password
# @param [String] password, new password
# @param [String] password_confirm, password confirmation (used to make sure the passwords match)
# @param [Integer] user_id, the ID of the user
get '/users/:id/password/edit' do
    loggedin(result)
    password = params["password"]
    password_confirm = params["password_confirm"]
    user_id = params["user_id"].to_i

    if result[0][0] == user_id
        if password == password_confirm
            if password.length < 6 or (password =~ /\d/).nil?
                user_edit_message = "Password needs to be at least six characters long, and contain a number."
                redirect back
            else
                dbupdate(:users, :password_digest, :user_id, [bcrypt(password), user_id])
                user_edit_message = "Password successfully changed!"

                redirect back
            end
        else
            user_edit_message = "Passwords don't match!"
            redirect back
        end
    end
    error_message = "You don't have the authority to make that decision. What are you doing?"
    redirect to ("/error")

end


# Updates story progression after the user makes a choice.
# @param [Integer] choice, The ID of the choice just made
post("/game/edit") do
    loggedin(result)
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

# Error page. Shown when the user making a request doesn't match the user affected by the request.
get("/error") do
    result = ""

    slim(:error, locals:{error_message: error_message})
end