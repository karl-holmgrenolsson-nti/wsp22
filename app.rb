require 'sinatra'
require 'slim'
require 'sqlite3'

get("/drinks/new") do
    slim(:"drinks/new")
end
