require 'sinatra'
require 'sinatra/content_for'
require 'sinatra/reloader' if development?
require 'tilt/erubis'

configure do
  enable :sessions
  set :session_secret, 'secret'
  set :erb, escape_html: true
end

helpers do
  def list_complete?(list)
    !list_empty?(list) && todos_remaining_count(list).zero?
  end

  def list_empty?(list)
    todos_count(list).zero?
  end

  def todos_count(list)
    list[:todos].size
  end

  def todos_remaining_count(list)
    list[:todos].count { |todo| !todo[:completed] }
  end

  def list_class(list)
    'complete' if list_complete?(list)
  end

  def sort_lists(lists, &block)
    lists.sort_by { |list| list_complete?(list) ? 1 : 0 }.each(&block)
  end

  def sort_todos(todos, &block)
    todos.sort_by { |todo| todo[:completed] ? 1 : 0 }.each(&block)
  end

  def h(content)
    Rack::Utils.escape_html(content)
  end
end

#==============================================================================
#==============================================================================
#==============================================================================

class SessionPersistence
  def initialize(session)
    @session = session
    @session[:lists] ||= []
  end

  def find_list(list_id)
    all_lists.find { |list| list[:id] == list_id }
  end

  def all_lists
    @session[:lists]
  end

  def error
    @session[:error]
  end

  def error=(msg)
    @session[:error] = msg
  end

  def success
    @session[:success]
  end

  def success=(msg)
    @session[:success] = msg
  end

  def list_exists?(list_id)
    !!find_list(list_id)
  end

  def create_new_list(list_name)
    list_id = next_element_id(all_lists)
    all_lists << { id: list_id, name: list_name, todos: [] }
  end

  def delete_list(list_id)
    all_lists.delete(find_list(list_id))
  end

  def create_new_todo(list, todo_name)
    todo_id = next_element_id(list[:todos])
    list[:todos] << { id: todo_id, name: todo_name, completed: false }
  end

  def delete_todo(list, todo_id)
    list[:todos].delete(find_todo(list, todo_id))
  end

  def find_todo(list, todo_id)
    list[:todos].find { |todo| todo[:id] == todo_id }
  end

  def update_list_name(list, list_name)
    list[:name] = list_name
  end

  def update_todo_status(list, todo_id, is_completed)
    todo = find_todo(list, todo_id)
    todo[:completed] = is_completed
  end

  def complete_all_todos(list)
    list[:todos].each { |todo| todo[:completed] = true }
  end

  private

  def next_element_id(arr)
    max = arr.map { |elem| elem[:id] }.max || 0
    max + 1
  end
end

#==============================================================================
#==============================================================================
#==============================================================================

def load_id_and_list
  list_id = params[:list_id]
  unless list_id =~ /\A\d+\z/ && @storage.list_exists?(list_id)
    @storage.error = 'The specified list was not found.'
    redirect '/lists'
  end
  list_id = list_id.to_i
  list = @storage.find_list(list_id)

  [list_id, list]
end

# Return an error message if list name is invalid. Return nil if name is valid.
def error_for_list_name(name)
  if !name.size.between?(1, 100)
    'List name must be between 1 and 100 characters.'
  elsif @storage.all_lists.any? { |list| list[:name] == name }
    'List name must be unique.'
  end
end

# Return an error message if list name is invalid. Return nil if name is valid.
def error_for_todo(name)
  'Todo name must be between 1 and 100 characters.' unless name.size.between?(1, 100)
end

before do
  @storage = SessionPersistence.new(session)
end

get '/' do
  redirect '/lists'
end

# View list of lists
get '/lists' do
  @lists = @storage.all_lists
  erb :lists, layout: :layout
end

# Render the new list form
get '/lists/new' do
  erb :new_list, layout: :layout
end

# Create a new list
post '/lists' do
  list_name = params[:list_name].strip

  error = error_for_list_name(list_name)
  if error
    @storage.error = error
    erb :new_list, layout: :layout
  else
    @storage.create_new_list(list_name)
    @storage.success = 'The list has been created.'
    redirect '/lists'
  end
end

# View a single todo list
get '/lists/:list_id' do
  @list_id, @list = load_id_and_list
  erb :list, layout: :layout
end

# Edit an existing todo list
get '/lists/:list_id/edit' do
  @list_id, @list = load_id_and_list
  erb :edit_list, layout: :layout
end

# Update an existing todo list
post '/lists/:list_id' do
  list_name = params[:list_name].strip
  @list_id, @list = load_id_and_list

  error = error_for_list_name(list_name)
  if error
    @storage.error = error
    erb :edit_list, layout: :layout
  else
    @storage.update_list_name(@list, list_name)
    @storage.success = 'The list has been updated.'
    redirect "/lists/#{@list_id}"
  end
end

# Delete a todo list
post '/lists/:list_id/delete' do
  @list_id = load_id_and_list.first

  @storage.delete_list(@list_id)
  if env['HTTP_X_REQUESTED_WITH'] == 'XMLHttpRequest'
    '/lists'
  else
    @storage.success = 'The list has been deleted.'
    redirect '/lists'
  end
end

# Add a new todo to a list
post '/lists/:list_id/todos' do
  @list_id, @list = load_id_and_list
  todo_name = params[:todo].strip

  error = error_for_todo(todo_name)
  if error
    @storage.error = error
    erb :list, layout: :layout
  else
    @storage.create_new_todo(@list, todo_name)
    @storage.success = 'The todo was added.'
    redirect "/lists/#{@list_id}"
  end
end

# Delete a todo from a list
post '/lists/:list_id/todos/:todo_id/delete' do
  @list_id, @list = load_id_and_list
  todo_id = params[:todo_id].to_i

  @storage.delete_todo(@list, todo_id)
  if env['HTTP_X_REQUESTED_WITH'] == 'XMLHttpRequest'
    status 204
  else
    @storage.success = 'The todo has been deleted.'
    redirect "/lists/#{@list_id}"
  end
end

# Update status of a todo
post '/lists/:list_id/todos/:todo_id' do
  @list_id, @list = load_id_and_list
  todo_id = params[:todo_id].to_i
  is_completed = params[:completed] == 'true'

  @storage.update_todo_status(@list, todo_id, is_completed)
  @storage.success = 'The todo has been updated.'
  redirect "/lists/#{@list_id}"
end

# Mark all todos as complete for a list
post '/lists/:list_id/complete_all' do
  @list_id, @list = load_id_and_list

  @storage.complete_all_todos(@list)
  @storage.success = 'All todos have been completed.'
  redirect "/lists/#{@list_id}"
end
