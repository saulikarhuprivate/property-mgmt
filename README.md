# Property Management System

## Prerequisites
1.  Google Cloud SDK installed and authenticated.
2.  Terraform installed.
3.  Python 3.11+ installed.
4.  Node.js 18+ installed.

## Setup

### Infrastructure
1.  Navigate to `infra/`.
2.  Run `terraform init`.
3.  Run `terraform apply`.

### Backend
1.  Navigate to `backend/`.
2.  Install dependencies: `pip install -r requirements.txt`.
3.  Run locally: `python app.py`.

### Frontend
1.  Navigate to `frontend/`.
2.  Install dependencies: `npm install`.
3.  Run locally: `npm run dev`.

## Architecture
-   **Frontend**: Vue.js + Vite
-   **Backend**: Python Flask (Cloud Run)
-   **Database**: Firestore
-   **Analytics**: BigQuery
-   **Processing**: Cloud Functions (triggered by GCS uploads)
