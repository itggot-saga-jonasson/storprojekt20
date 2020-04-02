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
    if find.kind_of?(Array) == false
        variables = find
    else
        variables = ""
        i = 0
        while i < find.length
            variables += find[i].to_s
            i += 1
            if i < find.length
                variables += ", "
            end
        end
    end

    if condition.kind_of?(Array) == false
        cond = condition.to_s + "=?"
    else
        cond = ""
        i = 0
        while i < condition.length
            cond += condition[i].to_s + "=?"
            i += 1
            if i < condition.length
                cond += " AND "
            end
        end
    end
    return db.execute("SELECT #{variables} FROM #{table} WHERE #{cond}", condition_name)
end

def dbselect2(find, table)
    if find.kind_of?(Array) == false
        variables = find
    else
        variables = ""
        i = 0
        while i < find.length
            variables += find[i].to_s
            i += 1
            if i < find.length
                variables += ", "
            end
        end
    end
    return db.execute("SELECT #{variables} FROM #{table}")
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

def dbupdate(table, variables, condition, variable_names)


    return db.execute("UPDATE #{table} SET #{variables} WHERE #{condition}", variable_names)
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