require "sinatra"
require "sinatra/reloader"
require "slim"
require "sqlite3"
require "bcrypt"

enable :sessions

public_routes = [
  "/login",
  "/signup",
  "/customers",
  "/"
]

before do
  if !(public_routes.include? request.path_info) && !session[:user_id]
    redirect("/login")
  end
end

def connect_to_db()
  db = SQLite3::Database.new("db/database.db")
  db.results_as_hash = true

  return db
end

def is_admin(user_id = session[:user_id])
  db = connect_to_db()

  if (!user_id)
    return false
  else
    user = db.execute("SELECT * FROM customer WHERE id = ?", user_id).first
    return user["admin"] === 1
  end
end

helpers do
  def user_is_admin()
    return is_admin(session[:user_id])
  end
end

get("/") do
  slim(:start)
end

get("/products") do
  db = connect_to_db()
  products = db.execute("SELECT * FROM product")

  slim(:"products/index", locals: {
                            products: products,
                          })
end

get("/products/new") do
  if (!is_admin())
    return "You must be admin to access this route"
  end

  slim(:"products/new")
end

post("/products") do
  if (!is_admin())
    return "You must be admin to access this route"
  end

  price = params[:price]
  name = params[:name]

  db = connect_to_db()
  db.execute("INSERT INTO product (price, name) VALUES (?, ?)", price, name)

  redirect("/products/new")
end

post("/products/:id/destroy") do
  if (!is_admin())
    return "You must be admin to access this route"
  end

  db = connect_to_db()
  db.execute("DELETE FROM product WHERE id = ?", params[:id])

  redirect("/products")
end

get("/login") do
  slim(:login)
end

get("/signup") do
  slim(:signup)
end

post("/login") do
  username = params[:username]
  password = params[:password]

  db = connect_to_db()
  user = db.execute("SELECT * FROM customer WHERE username = ?", username).first

  if (!user)
    return "Invalid username or password"
  end

  password_hash = user["password"]

  if BCrypt::Password.new(password_hash) == password
    session[:user_id] = user["id"]
    redirect("/products")
  else
    return "Invalid username or password"
  end
end

post("/customers") do
  username = params[:username]
  password = params[:password]

  password_hash = BCrypt::Password.create(password)

  db = connect_to_db()
  db.execute("INSERT INTO customer (username, password) VALUES (?, ?)", username, password_hash)

  user_id = db.last_insert_row_id

  session[:user_id] = user_id

  redirect("/products")
end

get("/orders") do
  db = connect_to_db()
  orders = db.execute("SELECT orders.*, customer.username, product.name as drink_name, product.price as drink_price FROM orders 
    LEFT JOIN customer ON customer.id = orders.customer_id
    LEFT JOIN product ON product.id = orders.product_id
    WHERE customer_id = ? AND complete = 0", session[:user_id])

  all_orders = []
  all_complete_orders = []

  if (is_admin())
    all_orders = db.execute("SELECT orders.*, customer.username, product.name as drink_name, product.price as drink_price FROM orders 
    LEFT JOIN customer ON customer.id = orders.customer_id
    LEFT JOIN product ON product.id = orders.product_id
    WHERE complete = 0")

    all_complete_orders = db.execute("SELECT orders.*, customer.username, product.name as drink_name, product.price as drink_price FROM orders 
    LEFT JOIN customer ON customer.id = orders.customer_id
    LEFT JOIN product ON product.id = orders.product_id
    WHERE complete = 1
    LIMIT 20")
  end

  slim(:"orders/index", locals: {
                          my_orders: orders,
                          all_orders: all_orders,
                          all_complete_orders: all_complete_orders,
                        })
end

get("/orders/new") do
  if (!is_admin())
    return "You must be admin to access this route"
  end
  slim(:"orders/new")
end

post("/orders") do
  product_id = params[:product_id]
  customer_id = session[:user_id]

  db = connect_to_db()
  db.execute("INSERT INTO orders (product_id, customer_id) VALUES (?, ?)", product_id, customer_id)

  redirect("/orders")
end

post("/orders/:order_id/complete") do
  if (!is_admin())
    return "You must be admin to access this route"
  end

  order_id = params[:order_id]

  db = connect_to_db()
  db.execute("UPDATE orders SET complete = 1 WHERE id = ?", order_id)

  redirect("/orders")
end

post("/orders/:id/destroy") do
  if (!is_admin())
    return "You must be admin to access this route"
  end

  db = connect_to_db()
  db.execute("DELETE FROM orders WHERE id = ?", params[:id])

  redirect("/orders")
end
