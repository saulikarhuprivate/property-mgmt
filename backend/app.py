import os
import firebase_admin
from firebase_admin import credentials, auth
from flask import Flask, request, jsonify
from flask_cors import CORS
from datetime import datetime
from google.cloud import storage
from google.auth.credentials import AnonymousCredentials

# Initialize Firebase Admin SDK
cred = None
key_path = "property-mgmt-app-key.json"

if os.path.exists(key_path):
    cred = credentials.Certificate(key_path)
    firebase_admin.initialize_app(cred)
else:
    # In Cloud Run/GCP or local emulator, default credentials/env vars are used
    # Explicitly set project_id for local emulator consistency
    project_id = os.environ.get('GOOGLE_CLOUD_PROJECT')
    if project_id:
        firebase_admin.initialize_app(options={'projectId': project_id})
    else:
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
            print(f"Token verification failed: {e}")
            return jsonify({"error": f"Invalid token: {str(e)}"}), 401
        
        return f(*args, **kwargs)
    wrapper.__name__ = f.__name__
    return wrapper

@app.route('/health', methods=['GET'])
def health_check():
    return jsonify({"status": "healthy"}), 200

@app.route('/', methods=['GET'])
def index():
    return jsonify({"message": "Welcome to the Property Management API", "status": "running"}), 200

@app.route('/upload', methods=['POST'])
@verify_token
def upload_file():
    if 'file' not in request.files:
        return jsonify({"error": "No file part"}), 400
    
    file = request.files['file']
    if file.filename == '':
        return jsonify({"error": "No selected file"}), 400
    
    provider = request.form.get('provider')
    if not provider:
         return jsonify({"error": "No provider specified"}), 400

    if file:
        # Upload to GCS: uploads/{user_id}/{provider}/{filename}
        try:
            from google.cloud import storage
            
            # Initialize Storage Client
            # In local dev with emulators, this should work if env vars are set
            # But the 'google-cloud-storage' lib might need configuration to point to emulator
            
            bucket_name = os.environ.get('STORAGE_BUCKET_NAME', 'local-uploads')
            
            # When using emulator, we need to ensure the client connects to it
            # The python client checks STORAGE_EMULATOR_HOST env var automatically
            if os.environ.get('STORAGE_EMULATOR_HOST'):
                 print(f"Using Storage Emulator at {os.environ.get('STORAGE_EMULATOR_HOST')}")
                 storage_client = storage.Client(credentials=AnonymousCredentials(), project=os.environ.get('GOOGLE_CLOUD_PROJECT', 'property-mgmt-local'))
            else:
                 storage_client = storage.Client()
            
            try:
                bucket = storage_client.get_bucket(bucket_name)
            except Exception:
                # Create bucket if it doesn't exist (local dev)
                bucket = storage_client.create_bucket(bucket_name)
            
            # Create a blob
            user_id = request.user['uid']
            timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
            filename = f"{provider}-{timestamp}.csv"
            
            # Use uploads/{user_id}/{provider}/ as the folder structure
            blob_name = f"uploads/{user_id}/{provider}/{filename}"
            blob = bucket.blob(blob_name)
            
            blob.upload_from_file(file)
            
            return jsonify({
                "message": f"File uploaded successfully as '{filename}'",
                "path": blob_name
            }), 200
            
        except Exception as e:
            return jsonify({"error": str(e)}), 500

if __name__ == "__main__":
    app.run(host='0.0.0.0', port=int(os.environ.get('PORT', 8080)))
