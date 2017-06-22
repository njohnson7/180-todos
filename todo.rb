require 'sinatra'
require 'sinatra/content_for'
require 'tilt/erubis'

require_relative 'database_persistence'

configure do
  enable :sessions
  set :session_secret, 'secret'
  set :erb, escape_html: true
end

configure(:development) do
  require 'sinatra/reloader'
  also_reload 'database_persistence.rb'
end

helpers do
  def list_complete?(list)
    !list_empty?(list) && list[:todos_remaining_count].zero?
  end

  def list_empty?(list)
    list[:todos_count].zero?
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

def load_list_id_and_list
  list_id = params[:list_id]
  list = @storage.find_list(list_id.to_i)
  unless list_id =~ /\A\d+\z/ && list
    ### @storage.error = 'The specified list was not found.'
    session[:error] = 'The specified list was not found.'
    redirect '/lists'
  end

  [list_id.to_i, list]
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
  @storage = DatabasePersistence.new(logger)
end

after do
  puts
end

get '/' do
  redirect '/lists'
end

# View list of lists
get '/lists' do
  @lists = @storage.all_lists
  erb :lists
end

# Render the new list form
get '/lists/new' do
  erb :new_list
end

# Create a new list
post '/lists' do
  list_name = params[:list_name].strip

  error = error_for_list_name(list_name)
  if error
    ### @storage.error = error
    session[:error] = error
    erb :new_list
  else
    @storage.create_new_list(list_name)
    ### @storage.success = 'The list has been created.'
    session[:success] = 'The list has been created.'
    redirect '/lists'
  end
end

# View a single todo list
get '/lists/:list_id' do
  @list_id, @list = load_list_id_and_list
  @todos = @storage.find_todos_for_list(@list_id)
  erb :list
end

# Edit an existing todo list
get '/lists/:list_id/edit' do
  @list_id, @list = load_list_id_and_list
  erb :edit_list
end

# Update an existing todo list
post '/lists/:list_id' do
  new_list_name = params[:list_name].strip
  @list_id, @list = load_list_id_and_list

  error = error_for_list_name(new_list_name)
  if error
    ### @storage.error = error
    session[:error] = error
    erb :edit_list
  else
    @storage.update_list_name(@list_id, new_list_name)
    ### @storage.success = 'The list has been updated.'
    session[:success] = 'The list has been updated.'
    redirect "/lists/#{@list_id}"
  end
end

# Delete a todo list
post '/lists/:list_id/delete' do
  @list_id = load_list_id_and_list.first

  @storage.delete_list(@list_id)
  if env['HTTP_X_REQUESTED_WITH'] == 'XMLHttpRequest'
    '/lists'
  else
    ### @storage.success = 'The list has been deleted.'
    session[:success] = 'The list has been deleted.'
    redirect '/lists'
  end
end

# Add a new todo to a list
post '/lists/:list_id/todos' do
  @list_id, @list = load_list_id_and_list
  todo_name = params[:todo].strip

  error = error_for_todo(todo_name)
  if error
    @todos = @storage.find_todos_for_list(@list_id)
    ### @storage.error = error
    session[:error] = error
    erb :list
  else
    @storage.create_new_todo(@list_id, todo_name)
    ### @storage.success = 'The todo was added.'
    session[:success] = 'The todo was added.'
    redirect "/lists/#{@list_id}"
  end
end

# Delete a todo from a list
post '/lists/:list_id/todos/:todo_id/delete' do
  @list_id, @list = load_list_id_and_list
  todo_id = params[:todo_id].to_i

  @storage.delete_todo(@list_id, todo_id)
  if env['HTTP_X_REQUESTED_WITH'] == 'XMLHttpRequest'
    status 204
  else
    ### @storage.success = 'The todo has been deleted.'
    session[:success] = 'The todo has been deleted.'
    redirect "/lists/#{@list_id}"
  end
end

# Update status of a todo
post '/lists/:list_id/todos/:todo_id' do
  @list_id, @list = load_list_id_and_list
  todo_id = params[:todo_id].to_i
  is_completed = params[:completed] == 'true'

  @storage.update_todo_status(todo_id, is_completed)
  ### @storage.success = 'The todo has been updated.'
  session[:success] = 'The todo has been updated.'
  redirect "/lists/#{@list_id}"
end

# Mark all todos as complete for a list
post '/lists/:list_id/complete_all' do
  @list_id, @list = load_list_id_and_list

  @storage.complete_all_todos(@list_id)
  ### @storage.success = 'All todos have been completed.'
  session[:success] = 'All todos have been completed.'
  redirect "/lists/#{@list_id}"
end
