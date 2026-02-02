import functions_framework
from google.cloud import storage
from google.cloud import bigquery
import pandas as pd
import io
import os
import json
from datetime import datetime

# Triggered by a change to a Cloud Storage bucket
@functions_framework.cloud_event
def process_upload(cloud_event):
    data = cloud_event.data
    bucket_name = data["bucket"]
    file_name = data["name"]
    
    print(f"Processing file: {file_name} from bucket: {bucket_name}")

    # Expected path: uploads/{customer_id}/{provider}/{property_id}/{filename}
    # Or simplified: uploads/{customer_id}/{provider}/{filename} 
    
    parts = file_name.split("/")
    # Basic validation of path structure
    if len(parts) < 3:
        print(f"Skipping file {file_name}: path structure too short")
        return
        
    if parts[0] != "uploads":
        print(f"Skipping file {file_name}: not in uploads/ directory")
        return

    customer_id = parts[1]
    provider = parts[2]
    # property_id = parts[3] # Optional if structure allows
    
    storage_client = storage.Client()
    bucket = storage_client.bucket(bucket_name)
    blob = bucket.blob(file_name)
    content = blob.download_as_text()
    
    # Parse CSV based on provider
    try:
        df = parse_csv(content, provider)
        if df is not None and not df.empty:
            df['customer_id'] = customer_id
            df['provider'] = provider
            # Assuming property_id is handled in parsing or assigned here
            if 'property_id' not in df.columns:
                 df['property_id'] = 'default-property' # Placeholder
                 
            insert_into_bigquery(df)
        else:
            print(f"No valid data extracted from {file_name}")
            
    except Exception as e:
        print(f"Error processing file {file_name}: {e}")

def parse_csv(content, provider):
    try:
        csv_file = io.StringIO(content)
        
        # Load settings for the provider
        settings_path = os.path.join(os.path.dirname(__file__), 'upload_formats', provider, 'settings.json')
        if not os.path.exists(settings_path):
            print(f"No settings found for provider: {provider}")
            return None
            
        with open(settings_path, 'r', encoding='utf-8') as f:
            settings = json.load(f)
            
        csv_config = settings.get('csv_settings', {})
        column_mapping = settings.get('column_mapping', {})
        timestamp_fmt = settings.get('timestamp_format')
        
        # Read CSV using settings
        df = pd.read_csv(csv_file, **csv_config)
        
        # Rename columns based on mapping
        # Invert mapping? No, mapping is "CSV Header" -> "Internal Name"
        # Rename expects { "Old": "New" } which matches our settings structure
        df = df.rename(columns=column_mapping)
        
        required_cols = ['timestamp', 'consumption_kwh']
        
        available_cols = df.columns.tolist()
        if not all(col in available_cols for col in required_cols):
             print(f"Missing required columns in CSV for provider {provider}. Columns found: {available_cols}")
             return None
            
        # Parse timestamp with specific format
        if timestamp_fmt:
            df['timestamp'] = pd.to_datetime(df['timestamp'], format=timestamp_fmt, errors='coerce')
        else:
            df['timestamp'] = pd.to_datetime(df['timestamp'], errors='coerce')

        # Ensure correct types
        df['consumption_kwh'] = pd.to_numeric(df['consumption_kwh'], errors='coerce')
        
        # Clean NaNs
        df = df.dropna(subset=['timestamp', 'consumption_kwh'])

        return df[required_cols]
    except Exception as e:
        print(f"Error parsing CSV: {e}")
        return None

def insert_into_bigquery(df):
    client = bigquery.Client()
    table_id = os.environ.get("BIGQUERY_TABLE", "sauli-propertymgmt.energy_data.consumption")
    
    job_config = bigquery.LoadJobConfig(
        write_disposition="WRITE_APPEND",
    )
    
    job = client.load_table_from_dataframe(
        df, table_id, job_config=job_config
    )
    job.result()
    print(f"Loaded {job.output_rows} rows into {table_id}")
