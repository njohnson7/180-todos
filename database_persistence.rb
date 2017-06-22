require 'pg'

class DatabasePersistence
  def initialize(logger)
    @db = if Sinatra::Base.production?
            PG.connect(ENV['DATABASE_URL'])
          else
            PG.connect(dbname: 'todos')
          end
    @logger = logger
  end

  def query(statement, *params)
    # @logger.info "#{statement} : #{params}"
    puts "  ==> #{statement} : #{params}"
    @db.exec_params(statement, params)
  end

  def find_list(list_id)
    sql = <<~SQL
      SELECT lists.*,
              count(todos.id) AS todos_count,
              count(nullif(todos.completed, true)) AS todos_remaining_count
         FROM lists
           LEFT JOIN todos ON todos.list_id = lists.id
         GROUP BY lists.id
         HAVING lists.id = $1;
    SQL
    result = query(sql, list_id)

    tuple = result.first
    return unless tuple

    tuple_to_list_hash(tuple)
  end

  def all_lists
    sql = <<~SQL
      SELECT lists.*,
             count(todos.id) AS todos_count,
             count(nullif(todos.completed, true)) AS todos_remaining_count
        FROM lists
          LEFT JOIN todos ON todos.list_id = lists.id
        GROUP BY lists.id
        ORDER BY lists.name;
    SQL
    result = query(sql)

    result.map { |tuple| tuple_to_list_hash(tuple) }
  end

  def create_new_list(list_name)
    sql = 'INSERT INTO lists (name) VALUES ($1)'
    query(sql, list_name)
  end

  def delete_list(list_id)
    sql = 'DELETE FROM lists WHERE id = $1'
    query(sql, list_id)
  end

  def create_new_todo(list_id, todo_name)
    sql = 'INSERT INTO todos (list_id, name) VALUES ($1, $2)'
    query(sql, list_id, todo_name)
  end

  def delete_todo(list_id, todo_id)
    sql = 'DELETE FROM todos WHERE id = $1 AND list_id = $2'
    query(sql, todo_id, list_id)
  end

  def update_list_name(list_id, new_name)
    sql = 'UPDATE lists SET name = $1 WHERE id = $2'
    query(sql, new_name, list_id)
  end

  def update_todo_status(todo_id, new_status)
    sql = 'UPDATE todos SET completed = $1 WHERE id = $2'
    query(sql, new_status, todo_id)
  end

  def complete_all_todos(list_id)
    sql = 'UPDATE todos SET completed = true WHERE list_id = $1'
    query(sql, list_id)
  end

  def find_todos_for_list(list_id)
    sql = 'SELECT * FROM todos WHERE list_id = $1 ORDER BY name'
    result = query(sql, list_id)

    result.map do |tuple|
      { id:        tuple['id'].to_i,
        name:      tuple['name'],
        completed: tuple['completed'] == 't' }
    end
  end

  private

  def tuple_to_list_hash(tuple)
    { id:                    tuple['id'].to_i,
      name:                  tuple['name'],
      todos_count:           tuple['todos_count'].to_i,
      todos_remaining_count: tuple['todos_remaining_count'].to_i }
  end
end
