<script setup>
import { ref, onMounted } from 'vue'
import { auth, loginWithGoogle, logout } from './firebase.js'
import { onAuthStateChanged } from 'firebase/auth'
import ConsumptionUpload from './energy-consumption/ConsumptionUpload.vue'

const apiMessage = ref('Checking backend connection...')
const isConnected = ref(false)
const user = ref(null)
const isLoading = ref(true)

const API_URL = import.meta.env.VITE_API_URL || 'http://localhost:5000'

onMounted(async () => {
  // Check backend health
  try {
    const response = await fetch(`${API_URL}/`)
    const data = await response.json()
    apiMessage.value = data.message
    isConnected.value = true
  } catch (error) {
    apiMessage.value = 'Error: Cannot connect to backend API'
    isConnected.value = false
    console.error(error)
  }

  // Monitor auth state
  onAuthStateChanged(auth, (currentUser) => {
    user.value = currentUser;
    isLoading.value = false;
  });
});

const handleLogin = async () => {
  try {
    await loginWithGoogle();
  } catch (error) {
    alert("Login failed: " + error.message);
  }
};

const handleLogout = async () => {
  await logout();
  user.value = null;
};
</script>

<template>
  <div class="container">
    <header v-if="user" class="app-header">
      <nav>
        <a href="#" class="nav-link">Main</a>
        <button @click="handleLogout" class="logout-btn">Logout</button>
      </nav>
      <div class="user-info">Logged in as: {{ user.email }}</div>
    </header>

    <main>
      <h1>Property Management System</h1>
      
      <div v-if="isLoading" class="loading">Loading...</div>

      <div v-else-if="!user" class="welcome-section">
        <p>Welcome to the Property Management System.</p>
        <p>Please log in to access the dashboard and upload data.</p>
        <button @click="handleLogin" class="login-btn">Log in with Google</button>
      </div>

      <div v-else class="dashboard">
        <div class="status-box" :class="{ connected: isConnected }">
          <p><strong>Backend Status:</strong> {{ apiMessage }}</p>
        </div>

        <div v-if="isConnected">
          <ConsumptionUpload :user="user" :api-url="API_URL" />
        </div>
      </div>
    </main>
  </div>
</template>

<style scoped>
/* ...existing code... */
.container {
  max-width: 800px;
  margin: 0 auto;
  padding: 2rem;
  font-family: Arial, sans-serif;
}

.app-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 2rem;
  padding-bottom: 1rem;
  border-bottom: 1px solid #eee;
}

.nav-link {
  margin-right: 1rem;
  text-decoration: none;
  color: #2c3e50;
  font-weight: bold;
}

.logout-btn {
  background-color: #f44336;
  color: white;
  padding: 5px 10px;
  border: none;
  border-radius: 4px;
  cursor: pointer;
}

.login-btn {
  background-color: #4285F4;
  color: white;
  padding: 10px 20px;
  font-size: 16px;
  border: none;
  border-radius: 4px;
  cursor: pointer;
}

.welcome-section {
  text-align: center;
  margin-top: 3rem;
}

.status-box {
  padding: 1rem;
  margin: 1rem 0;
  border-radius: 8px;
  background-color: #ffebee;
  border: 1px solid #ffcdd2;
}

.status-box.connected {
  background-color: #e8f5e9;
  border: 1px solid #c8e6c9;
}

h1 {
  color: #2c3e50;
  text-align: center;
}
</style>
