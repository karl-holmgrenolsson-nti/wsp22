require "sinatra"
require "slim"
require "sqlite3"

get ("/") do
  return "drinks"
end

get("/drinks/new") do
  slim(:"drinks/new")
end
