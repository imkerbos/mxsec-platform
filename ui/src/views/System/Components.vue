<template>
  <div class="system-components-page">
    <div class="page-header">
      <h2>组件列表</h2>
    </div>

    <a-card :bordered="false">
      <a-empty description="组件列表功能开发中..." />
    </a-card>
  </div>
</template>

<script setup lang="ts">
// 组件列表页面 - 后续基线等组件管理更新
</script>

<style scoped>
.system-components-page {
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
