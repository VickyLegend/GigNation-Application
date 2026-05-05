from flask import Flask, request, jsonify
from flask_sqlalchemy import SQLAlchemy
from flask_cors import CORS
from werkzeug.security import generate_password_hash, check_password_hash

app = Flask(__name__)
CORS(app)

app.config['SQLALCHEMY_DATABASE_URI'] = 'sqlite:///app.db'
app.config['SQLALCHEMY_TRACK_MODIFICATIONS'] = False

db = SQLAlchemy(app)

# ----------------------
# MODELS
# ----------------------

class User(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    email = db.Column(db.String(120), unique=True, nullable=False)
    password = db.Column(db.String(200), nullable=False)

class RequestModel(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    title = db.Column(db.String(200))
    description = db.Column(db.String(500))
    status = db.Column(db.String(50), default="pending")
    user_id = db.Column(db.Integer)

# ----------------------
# ROUTES
# ----------------------

@app.route('/status', methods=['GET'])
def status():
    return jsonify({"message": "Server is running"})


# REGISTER
@app.route('/register', methods=['POST'])
def register():
    data = request.json
    email = data.get("email")
    password = data.get("password")

    if User.query.filter_by(email=email).first():
        return jsonify({"error": "User already exists"}), 400

    hashed_password = generate_password_hash(password)

    user = User(email=email, password=hashed_password)
    db.session.add(user)
    db.session.commit()

    return jsonify({"message": "User registered successfully"})


# LOGIN
@app.route('/login', methods=['POST'])
def login():
    data = request.json
    email = data.get("email")
    password = data.get("password")

    user = User.query.filter_by(email=email).first()

    if not user or not check_password_hash(user.password, password):
        return jsonify({"error": "Invalid credentials"}), 401

    return jsonify({"message": "Login successful", "user_id": user.id})


# CREATE REQUEST
@app.route('/requests', methods=['POST'])
def create_request():
    data = request.json

    new_request = RequestModel(
        title=data.get("title"),
        description=data.get("description"),
        user_id=data.get("user_id")
    )

    db.session.add(new_request)
    db.session.commit()

    return jsonify({"message": "Request created"})


# GET ALL REQUESTS
@app.route('/requests', methods=['GET'])
def get_requests():
    requests = RequestModel.query.all()

    output = []
    for r in requests:
        output.append({
            "id": r.id,
            "title": r.title,
            "description": r.description,
            "status": r.status,
            "user_id": r.user_id
        })

    return jsonify(output)


# UPDATE REQUEST
@app.route('/requests/<int:id>', methods=['PUT'])
def update_request(id):
    data = request.json
    req = RequestModel.query.get(id)

    if not req:
        return jsonify({"error": "Not found"}), 404

    req.status = data.get("status", req.status)
    db.session.commit()

    return jsonify({"message": "Updated"})


# DELETE REQUEST
@app.route('/requests/<int:id>', methods=['DELETE'])
def delete_request(id):
    req = RequestModel.query.get(id)

    if not req:
        return jsonify({"error": "Not found"}), 404

    db.session.delete(req)
    db.session.commit()

    return jsonify({"message": "Deleted"})


# ----------------------
# RUN APP
# ----------------------

if __name__ == '__main__':
    with app.app_context():
        db.create_all()
    app.run(debug=True)