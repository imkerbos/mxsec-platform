<template>
  <div class="system-install-page">
    <div class="page-header">
      <h2>安装配置指引</h2>
    </div>

    <a-card :bordered="false">
      <a-tabs v-model:activeKey="activeTab" type="card">
        <a-tab-pane key="linux" tab="Linux">
          <LinuxInstallGuide />
        </a-tab-pane>
        <a-tab-pane key="kubernetes" tab="Kubernetes">
          <KubernetesInstallGuide />
        </a-tab-pane>
      </a-tabs>
    </a-card>
  </div>
</template>

<script setup lang="ts">
import { ref } from 'vue'
import LinuxInstallGuide from './components/LinuxInstallGuide.vue'
import KubernetesInstallGuide from './components/KubernetesInstallGuide.vue'

const activeTab = ref('linux')
</script>

<style scoped>
.system-install-page {
  width: 100%;
  padding: 24px;
}

.page-header {
  margin-bottom: 24px;
}

.page-header h2 {
  margin: 0;
  font-size: 20px;
  font-weight: 600;
}
</style>
