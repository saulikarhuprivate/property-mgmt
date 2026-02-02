# Local Development with Docker

This guide explains how to run the entire Property Management application stack locally on Windows using Docker and Docker Compose.

## Prerequisites

- Docker Desktop installed and running
- Docker Compose (included with Docker Desktop)
- Git

## What's Included

The `docker-compose.yml` sets up the following services:

| Service | Port | Purpose |
|---------|------|---------|
| **Backend** | 5000 | Flask API server |
| **Frontend** | 5173 | Vue.js dev server (Vite) |
| **Firestore Emulator** | 8080 | Local Firestore database |
| **BigQuery Emulator** | 3000 | Local BigQuery service |
| **MinIO** | 9000/9001 | S3-compatible storage (Cloud Storage simulation) |

## Quick Start

1. **Navigate to the project directory:**
   ```powershell
   cd property-mgmt
   ```

2. **Start all services:**
   ```powershell
   docker-compose up
   ```
   
   Or run in background:
   ```powershell
   docker-compose up -d
   ```

3. **Access the application:**
   - Frontend: http://localhost:5173
   - Backend API: http://localhost:5000
   - MinIO Console: http://localhost:9001 (admin/minioadmin)
   - Firestore Emulator UI: http://localhost:8080

4. **Stop all services:**
   ```powershell
   docker-compose down
   ```

## Development Workflow

### Making Changes

- **Backend changes**: Changes to Python files in `backend/` are automatically detected and reloaded
- **Frontend changes**: Changes to Vue.js files in `frontend/` are hot-reloaded by Vite
- No rebuild needed for code changes (except dependencies)

### Installing Backend Dependencies

If you add new Python packages:

```powershell
docker-compose exec backend pip install -r requirements.txt
```

### Installing Frontend Dependencies

If you add new npm packages:

```powershell
docker-compose exec frontend npm install
```

## Emulator Details

### Firestore Emulator
- Stores data in memory (not persisted between restarts)
- To persist data, modify the docker-compose.yml to add a volume
- All Firestore operations work as expected

### BigQuery Emulator
- Simulates BigQuery API responses
- Data is not persisted
- Use for testing BigQuery integrations

### MinIO (Cloud Storage)
- S3-compatible object storage
- Console available at http://localhost:9001
- Credentials: `minioadmin` / `minioadmin`
- Bucket created: `local-uploads`

## Troubleshooting

### Ports already in use
If a port is already in use, modify the port mapping in `docker-compose.yml`:
```yaml
ports:
  - "5000:5000"  # Change first number to different port
```

### Container won't start
Check logs:
```powershell
docker-compose logs [service-name]
```

Example:
```powershell
docker-compose logs backend
```

### Clear everything and start fresh
```powershell
docker-compose down -v  # -v removes volumes
docker-compose up --build
```

### Accessing container shell
```powershell
docker-compose exec backend bash      # Backend
docker-compose exec frontend bash     # Frontend
```

## Environment Variables

Backend environment variables are configured in `docker-compose.yml`:
- `FIRESTORE_EMULATOR_HOST`: Points to Firestore emulator
- `BIGQUERY_EMULATOR_HOST`: Points to BigQuery emulator
- `STORAGE_BUCKET_NAME`: MinIO bucket name
- `GOOGLE_CLOUD_PROJECT`: Project ID for local development

Modify these in `docker-compose.yml` if needed.

## Notes

- The backend and frontend services have volume mounts for live code reloading
- Do NOT commit `node_modules` or Python `__pycache__` directories
- `.gitignore` should exclude Docker-specific files if not already configured
- For production, use the Cloud Build configuration in `cloudbuild.yaml`

## Next Steps

After local testing, deploy to Google Cloud using:
```powershell
gcloud builds submit
```

This triggers the Cloud Build pipeline defined in `cloudbuild.yaml`.
