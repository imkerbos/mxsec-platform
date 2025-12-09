<template>
  <a-card title="资产指纹" :bordered="false">
    <a-row :gutter="16">
      <a-col :span="3" v-for="item in fingerprintItems" :key="item.key">
        <a-card :bordered="false" style="text-align: center; cursor: pointer" hoverable>
          <div style="font-size: 24px; font-weight: bold; margin-bottom: 8px">{{ item.value }}</div>
          <div style="color: #8c8c8c">{{ item.label }}</div>
        </a-card>
      </a-col>
    </a-row>
  </a-card>
</template>

<script setup lang="ts">
import { ref, onMounted } from 'vue'

const props = defineProps<{
  hostId: string
}>()

const fingerprintItems = ref([
  { key: 'containers', label: '容器', value: 0 },
  { key: 'ports', label: '开放端口', value: 0 },
  { key: 'processes', label: '运行进程', value: 0 },
  { key: 'users', label: '系统用户', value: 0 },
  { key: 'cron', label: '定时任务', value: 0 },
  { key: 'services', label: '系统服务', value: 0 },
  { key: 'packages', label: '系统软件', value: 0 },
  { key: 'integrity', label: '系统完整性校验', value: 0 },
])

onMounted(() => {
  // TODO: 加载资产指纹数据
})
</script>
