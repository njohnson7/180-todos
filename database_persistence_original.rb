require 'pg'

class DatabasePersistence
  def initialize
    @db = PG.connect(dbname: 'todos')
  end

  def find_list(list_id)
    # all_lists.find { |list| list[:id] == list_id }
  end

  def all_lists
    sql = 'SELECT * FROM lists'
    result = @db.exec(sql)

    result.map { |tuple| { id: tuple['id'], name: tuple['name'], todos: [] } }
  end

  def error
    # @session[:error]
  end

  def error=(msg)
    # @session[:error] = msg
  end

  def success
    # @session[:success]
  end

  def success=(msg)
    # @session[:success] = msg
  end

  def list_exists?(list_id)
    # !!find_list(list_id)
  end

  def create_new_list(list_name)
    # list_id = next_element_id(all_lists)
    # all_lists << { id: list_id, name: list_name, todos: [] }
  end

  def delete_list(list_id)
    # all_lists.delete(find_list(list_id))
  end

  def create_new_todo(list, todo_name)
    # todo_id = next_element_id(list[:todos])
    # list[:todos] << { id: todo_id, name: todo_name, completed: false }
  end

  def delete_todo(list, todo_id)
    # list[:todos].delete(find_todo(list, todo_id))
  end

  def find_todo(list, todo_id)
    # list[:todos].find { |todo| todo[:id] == todo_id }
  end

  def update_list_name(list, list_name)
    # list[:name] = list_name
  end

  def update_todo_status(list, todo_id, is_completed)
    # todo = find_todo(list, todo_id)
    # todo[:completed] = is_completed
  end

  def complete_all_todos(list)
    # list[:todos].each { |todo| todo[:completed] = true }
  end
end
