<template>
  <div class="system-settings-page">
    <div class="page-header">
      <h2>基本设置</h2>
    </div>

    <a-card :bordered="false">
      <a-empty description="基本设置功能开发中..." />
    </a-card>
  </div>
</template>

<script setup lang="ts">
// 基本设置页面 - 系统时间NTP同步，产品信息（站点title和logo）
</script>

<style scoped>
.system-settings-page {
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
