# **Project Specification: Property Management (Working Title)**

This document defines the architecture, data model, and development process for a GCP-native property management system.

## **1\. Architectural Overview (Decoupled Model)**

* **Backend:** Python Flask REST API (Cloud Run)  
  * Handles JSON data, Signed URLs for file uploads, and BigQuery reports.  
* **Frontend:** Vue.js SPA (Vite).  
* **Authentication:** Google Identity Platform (Firebase Auth).  
* **Database:** Google Cloud Firestore (Native Mode).  
* **Analytics:** Google BigQuery.  
* **File Management:** Google Cloud Storage (GCS).  
* **Processing:** Cloud Functions (2nd Gen) \+ Eventarc.  
* **CI/CD:** Cloud Build.

## **2\. Data Model (Firestore)**

### **Collections:**

* /users/{userId}/properties/{propertyId}  
  * name, description, address, createdAt  
  * utilityProvider: (e.g., "lumme\_energia", "helen") – unique key corresponding to a parser config.  
* /metadata/counters  
  * lastCustomerId: An integer incremented atomically whenever a new user registers.

### **User Profile:**

Each user has a customerId (integer), which is stored in both Firestore and the BigQuery users table.

## **3\. Energy Consumption & BigQuery Pipeline**

### **Data Ingestion:**

1. **Schema Selection:** User selects the utility provider in the property settings.  
2. **Signed URL Upload:** CSV is uploaded to GCS. customerId, propertyId, and utilityProvider are added to the object metadata.  
3. **Cloud Function (Generic Normalizer):**  
   * Triggered by GCS upload.  
   * **Config-as-Code Strategy:** The function maintains a parsers/ directory containing mapping configurations (JSON or Python dicts) for each supported utilityProvider.  
   * **Parser Logic:** Reads metadata \-\> selects matching config \-\> normalizes CSV (e.g., mapping "Alkamisaika" to timestamp) \-\> cleanses data (handling encodings/date formats).  
   * Injects normalized data into the generic BigQuery table.

### **Reporting:**

* The Backend executes SQL queries that are always scoped: WHERE customer\_id \= {current\_user\_id}.

## **4\. BigQuery Schema (Generic)**

### **Table: users**

* customer\_id (INTEGER, Primary Key)  
* firebase\_uid (STRING)  
* display\_name (STRING)  
* created\_at (TIMESTAMP)

### **Table: energy\_consumption (Normalized Data)**

* customer\_id (INTEGER)  
* property\_id (STRING)  
* timestamp (TIMESTAMP) \- Start of the consumption period.  
* consumption\_kwh (FLOAT) \- Consumption for the period (kWh).  
* provider\_original\_name (STRING) \- Original provider name for auditing.  
* metadata (JSON) \- Extra data (e.g., temperature).

## **5\. Security & Isolation**

* **Data Access:** The Backend ensures that a user can only access data associated with their own customer\_id.  
* **Firestore:** Security Rules restrict access to the /users/{userId}/ path only.

## **6\. UI/UX Guidelines**

* **Profile Settings:** Users can see their own customer ID.  
* **Reports:** Dashboard featuring visualizations (e.g., hourly or monthly consumption) based on BigQuery data.