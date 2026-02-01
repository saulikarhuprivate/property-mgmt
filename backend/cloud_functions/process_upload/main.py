import functions_framework
from google.cloud import storage
from google.cloud import bigquery
import pandas as pd
import io
import os

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
        # TODO: Implement specific parsing logic for 'lumme_energia', 'helen', etc.
        # Simple generic parser for demo: expect Timestamp, Value
        df = pd.read_csv(csv_file)
        
        # Rename columns to match BQ schema
        # Schema: customer_id, property_id, timestamp, consumption_kwh, provider
        
        # Mapping logic
        column_map = {
            'Timestamp': 'timestamp',
            'Time': 'timestamp',
            'Date': 'timestamp',
            'Value': 'consumption_kwh',
            'Consumption': 'consumption_kwh',
            'Energy': 'consumption_kwh'
        }
        
        df = df.rename(columns=column_map)
        
        required_cols = ['timestamp', 'consumption_kwh']
        # Check if required columns exist (case insensitive maybe?)
        # For now, strict check
        
        available_cols = df.columns.tolist()
        # Simple check
        if not all(col in available_cols for col in required_cols):
             # Try to infer if not found? No, keep simple for now.
             print(f"Missing required columns in CSV for provider {provider}. Columns found: {available_cols}")
             return None
            
        df['timestamp'] = pd.to_datetime(df['timestamp'])
        # Ensure correct types
        df['consumption_kwh'] = pd.to_numeric(df['consumption_kwh'], errors='coerce')
        
        # Clean NaNs
        df = df.dropna(subset=['timestamp', 'consumption_kwh'])

        return df[required_cols] # Return only needed columns, customer_id etc added later
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
