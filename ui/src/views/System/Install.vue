<template>
  <div class="system-install-page">
    <div class="page-header">
      <h2>安装配置</h2>
    </div>

    <a-card :bordered="false">
      <a-empty description="安装配置功能开发中..." />
    </a-card>
  </div>
</template>

<script setup lang="ts">
// 安装配置页面 - 安装配置指引，比如Linux、Windows、K8s的agent安装
</script>

<style scoped>
.system-install-page {
  width: 100%;
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
