import os
import firebase_admin
from firebase_admin import credentials, auth
from flask import Flask, request, jsonify
from flask_cors import CORS

# Initialize Firebase Admin SDK
cred = None
key_path = "property-mgmt-app-key.json"

if os.path.exists(key_path):
    cred = credentials.Certificate(key_path)
    firebase_admin.initialize_app(cred)
else:
    # In Cloud Run/GCP, default credentials are used automatically
    firebase_admin.initialize_app()

app = Flask(__name__)
CORS(app)

def verify_token(f):
    def wrapper(*args, **kwargs):
        auth_header = request.headers.get('Authorization')
        if not auth_header:
            return jsonify({"error": "No Authorization header provided"}), 401
        
        try:
            token = auth_header.split(" ")[1]
            decoded_token = auth.verify_id_token(token)
            request.user = decoded_token # Attach user info to request
        except Exception as e:
            return jsonify({"error": "Invalid token"}), 401
        
        return f(*args, **kwargs)
    wrapper.__name__ = f.__name__
    return wrapper

@app.route('/health', methods=['GET'])
def health_check():
    return jsonify({"status": "healthy"}), 200

if __name__ == "__main__":
    app.run(host='0.0.0.0', port=int(os.environ.get('PORT', 8080)))
