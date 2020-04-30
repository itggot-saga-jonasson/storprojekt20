require "sqlite3"
require "bcrypt"
salt = "stark"

# Path to database
def db
    return SQLite3::Database.open("db/data.db")
end

# Name of salt
def salt
    return "stark"
end




# Returns values from a table that match the given condition(s)
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

#  Returns values from a table, no conditions
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

# Inserts new values into a table
def dbinsert(table, variables, variable_names)
    i = 1
    marks = "?"
    while i < variables.length
        marks += ",?"
        i += 1
    end

    v = ""
    i = 0
    while i < variables.length
        v += variables[i].to_s 
        i += 1
        if i < variables.length
            v += ", "
        end
    end

    return db.execute("INSERT INTO #{table}(#{v}) VALUES (#{marks})", variable_names)
end

# Updates values in a table that match the given condition(s)
def dbupdate(table, variables, condition, names)
    if variables.kind_of?(Array) == false
        v = variables.to_s + "=?"
    else
        v = ""
        i = 0
        while i < variables.length
            v += variables[i].to_s + "=?"
            i += 1
            if i < variables.length
                v += ", "
            end
        end
    end

    if condition.kind_of?(Array) == false
        c = condition.to_s + "=?"
    else
        c = ""
        i = 0
        while i < condition.length
            c += condition[i].to_s + "=?"
            i += 1
            if i < condition.length
                c += " AND "
            end
        end
    end

    return db.execute("UPDATE #{table} SET #{v} WHERE #{c}", names)
end

# Removes values from table that match the given condition(s)
def dbdelete(table, condition, condition_name)
    if condition.kind_of?(Array) == false
        c = condition.to_s + "=?"
    else
        c = ""
        i = 0
        while i < condition.length
            c += condition[i].to_s + "=?"
            i += 1
            if i < condition.length
                c += " AND "
            end
        end
    end

    return db.execute("DELETE FROM #{table} WHERE #{c}", condition_name)
end


# Encrypts a password
def bcrypt(string)
    return BCrypt::Password.create(string+salt)
end

# Compares given password with stored encrypted password
def password_compare(password, user_id)
    password_digest = db.execute("SELECT password_digest FROM users WHERE user_id=?", user_id)[0][0]
    if BCrypt::Password.new(password_digest) == password + salt
        return true
    else
        return false
    end

end