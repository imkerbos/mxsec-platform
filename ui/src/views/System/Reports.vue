<template>
  <div class="system-reports-page">
    <div class="page-header">
      <h2>报告管理</h2>
    </div>

    <a-card :bordered="false">
      <a-empty description="报告管理功能开发中..." />
    </a-card>
  </div>
</template>

<script setup lang="ts">
// 报告管理页面 - 新建报告和历史报告下载详情等，报告生成可以选择时间范围
</script>

<style scoped>
.system-reports-page {
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
