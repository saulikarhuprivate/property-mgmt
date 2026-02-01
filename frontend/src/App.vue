<script setup>
import { ref } from 'vue'

const msg = ref('Hello Vue 3 + Vite')
</script>

<template>
  <div class="container">
    <h1>Property Management System</h1>
    <p>{{ msg }}</p>
  </div>
</template>

<style scoped>
.container {
  max-width: 800px;
  margin: 0 auto;
  padding: 2rem;
  text-align: center;
}
h1 {
  color: #42b983;
}
</style>
