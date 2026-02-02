<script setup>
import { ref } from 'vue'

const props = defineProps(['user', 'apiUrl'])
const file = ref(null)
const uploadStatus = ref('')
const selectedFormat = ref('lumme-energia') // Default

// Available upload formats (hardcoded for now, could be fetched from API later)
const uploadFormats = [
  { value: 'lumme-energia', label: 'Lumme Energia Oy' }
]

const handleFileUpload = (event) => {
  file.value = event.target.files[0]
}

const uploadFile = async () => {
  if (!file.value || !props.user) return
  
  const formData = new FormData()
  formData.append('file', file.value)
  formData.append('provider', selectedFormat.value) // Send the provider format ID
  
  uploadStatus.value = 'Uploading...'
  
  try {
    const token = await props.user.getIdToken();
    const response = await fetch(`${props.apiUrl}/upload`, {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${token}`
      },
      body: formData
    })
    
    if (response.ok) {
      uploadStatus.value = 'File uploaded successfully!'
      file.value = null; // Clear input
    } else {
      const errorData = await response.json();
      uploadStatus.value = `Upload failed: ${errorData.error || response.statusText}`;
    }
  } catch (error) {
    uploadStatus.value = 'Error uploading file: ' + error.message
  }
}
</script>

<template>
  <div class="upload-section">
    <h2>Upload Consumption Data</h2>
    
    <div class="form-group">
      <label for="format-select">Upload Format:</label>
      <select id="format-select" v-model="selectedFormat">
        <option v-for="format in uploadFormats" :key="format.value" :value="format.value">
          {{ format.label }}
        </option>
      </select>
      <p class="format-desc" v-if="selectedFormat === 'lumme-energia'">
        Lumme Energian sivuilta saatu CSV-tiedosto, joka sisältää tuntikohtaisia kulutustietoja.
      </p>
    </div>

    <div class="form-group">
      <label for="file-upload">Select File:</label>
      <input id="file-upload" type="file" @change="handleFileUpload" accept=".csv" />
    </div>

    <button @click="uploadFile" :disabled="!file" class="upload-btn">Upload</button>
    <p v-if="uploadStatus" class="status-msg">{{ uploadStatus }}</p>
  </div>
</template>

<style scoped>
.upload-section {
  padding: 1.5rem;
  border: 1px solid #ddd;
  border-radius: 8px;
  background-color: #f9f9f9;
}

.form-group {
  margin-bottom: 1rem;
}

label {
  display: block;
  margin-bottom: 0.5rem;
  font-weight: bold;
}

select, input[type="file"] {
  padding: 0.5rem;
  border: 1px solid #ccc;
  border-radius: 4px;
  width: 100%;
  max-width: 400px;
}

.format-desc {
  font-size: 0.9rem;
  color: #666;
  margin-top: 0.25rem;
}

.upload-btn {
  margin-top: 10px;
  padding: 8px 16px;
  background-color: #4CAF50;
  color: white;
  border: none;
  border-radius: 4px;
  cursor: pointer;
}

button:disabled {
  background-color: #cccccc;
  cursor: not-allowed;
}

.status-msg {
  margin-top: 1rem;
  font-weight: bold;
}
</style>
