require "sqlite3"
require "bcrypt"
salt = "stark"

def db
    return SQLite3::Database.open("db/data.db")
end

def salt
    return "stark"
end





def dbselect(find, table, condition, condition_name)
    return db.execute("SELECT #{find} FROM #{table} WHERE #{condition}=?", condition_name)
end

def dbinsert(table, variables, variable_names)
    i = 1
    marks = "?"
    while i < variables.length
        marks += ",?"
        i += 1
    end

    return db.execute("INSERT INTO #{table}(#{variables}) VALUES (#{marks})", [variable_names])
end

def bcrypt(string)
    return BCrypt::Password.create(string+salt)
end


def password_compare(password, user_id)
    password_digest = db.execute("SELECT password_digest FROM users WHERE user_id=?", user_id)[0][0]
    if BCrypt::Password.new(password_digest) == password + salt
        return true
    else
        return false
    end

end