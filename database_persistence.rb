require 'pg'

class DatabasePersistence
  def initialize(logger)
    @db = PG.connect(dbname: 'todos')
    @logger = logger
  end

  def query(statement, *params)
    # @logger.info "#{statement} : #{params}"
    puts "  ==> #{statement} : #{params}"
    @db.exec_params(statement, params)
  end

  def find_list(list_id)
    # all_lists.find { |list| list[:id] == list_id }
      # returns: one list hash from lists array

    # all_lists.find { |list| list[:id] == list_id.to_i }


### FROM VIDEO...
    sql = 'SELECT * FROM lists WHERE id = $1'
    result = query(sql, list_id)

    result.map do |tuple|
      list_id = tuple['id'].to_i
      { id:    list_id,
        name:  tuple['name'],
        todos: find_todos_for_list(list_id) }
    end.first
  end

  def all_lists
    sql = 'SELECT * FROM lists'
    # result = @db.exec(sql)
    result = query(sql)

    result.map do |tuple|
      list_id = tuple['id'].to_i
      { id:    list_id,
        name:  tuple['name'],
        todos: find_todos_for_list(list_id) }
    end
  end

  def find_todos_for_list(list_id)
    sql = 'SELECT * FROM todos WHERE list_id = $1'
    # result = @db.exec_params(sql, [list_id])
    result = query(sql, list_id)

    result.map do |tuple|
      { id:        tuple['id'].to_i,
        name:      tuple['name'],
        completed: tuple['completed'] == 't' }
    end
  end

  def list_exists?(list_id)
    !!find_list(list_id.to_i)
  end

  def create_new_list(list_name)
    # list_id = next_element_id(all_lists)
    # all_lists << { id: list_id, name: list_name, todos: [] }

    sql = 'INSERT INTO lists (name) VALUES ($1)'
    @db.exec_params(sql, [list_name])
  end

  def delete_list(list_id)
    # all_lists.delete(find_list(list_id))

    sql = 'DELETE FROM lists WHERE id = $1'
    # @db.exec_params(sql, [list_id])
    query(sql, list_id)
  end

  def create_new_todo(list, todo_name)
    # todo_id = next_element_id(list[:todos])
    # list[:todos] << { id: todo_id, name: todo_name, completed: false }

    sql = 'INSERT INTO todos (name, list_id) VALUES ($1, $2)'
    # @db.exec_params(sql, [todo_name, list[:id]])
    query(sql, todo_name, list[:id])
  end

### FIX: remove list param from todo.rb...
    # def delete_todo(list, todo_id)
      # list[:todos].delete(find_todo(list, todo_id))
  def delete_todo(_, todo_id)

    sql = 'DELETE FROM todos WHERE id = $1'
    # @db.exec_params(sql, [todo_id])
    query(sql, todo_id)
  end

### FIX: remove this method from everywhere...
  # def find_todo(list, todo_id)
    # list[:todos].find { |todo| todo[:id] == todo_id }
  # end

  def update_list_name(list, new_name)
    # list[:name] = new_name

    sql = 'UPDATE lists SET name = $1 WHERE name = $2'
    # @db.exec_params(sql, [new_name, list[:name]])
    query(sql, new_name, list[:name])
  end

### FIX: remove list param from todo.rb...
  # def update_todo_status(list, todo_id, is_completed)
  def update_todo_status(_, todo_id, is_completed)
    # todo = find_todo(list, todo_id)
    # todo[:completed] = is_completed

    sql = 'UPDATE todos SET completed = $1 WHERE id = $2'
    # @db.exec_params(sql, [is_completed, todo_id])
    query(sql, is_completed, todo_id)
  end

  def complete_all_todos(list)
    # list[:todos].each { |todo| todo[:completed] = true }

    sql = 'UPDATE todos SET completed = true WHERE list_id = $1'
    # @db.exec_params(sql, [list[:id]])
    query(sql, list[:id])
  end

### FIX...?
  # def error=(msg)
  #   session[:error] = msg
  # end

  # def success=(msg)
  #   session[:success] = msg
  # end
end
