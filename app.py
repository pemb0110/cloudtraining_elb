from flask import Flask, render_template, request, redirect, url_for
import psycopg2

app = Flask(__name__)

# Database connection details (replace with your RDS credentials)
DATABASE_URL = "postgresql://myuser:mypassword@<RDS_ENDPOINT>:5432/mylistdb" # Replace <RDS_ENDPOINT>

# Function to add item to database
def add_item(item):
    try:
        conn = psycopg2.connect(DATABASE_URL)
        cur = conn.cursor()
        cur.execute("INSERT INTO items (item) VALUES (%s)", (item,))
        conn.commit()
        cur.close()
        conn.close()
        return True
    except Exception as e:
        print(f"Error adding item: {e}")
        return False

# Function to get all items from database
def get_items():
    try:
        conn = psycopg2.connect(DATABASE_URL)
        cur = conn.cursor()
        cur.execute("SELECT item FROM items")
        items = [row[0] for row in cur.fetchall()]
        cur.close()
        conn.close()
        return items
    except Exception as e:
        print(f"Error getting items: {e}")
        return []

@app.route("/", methods=["GET", "POST"])
def index():
    if request.method == "POST":
        item = request.form["item"]
        if add_item(item):
            return redirect(url_for("index"))
    items = get_items()
    return render_template("index.html", items=items)

@app.route("/show_list")
def show_list():
    items = get_items()
    return render_template("show_list.html", items=items)

if __name__ == "__main__":
    app.run(debug=True, host='0.0.0.0')