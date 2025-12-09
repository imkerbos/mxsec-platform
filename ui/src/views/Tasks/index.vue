<template>
  <div class="tasks-page">
    <div class="page-header">
      <h2>扫描任务</h2>
      <a-button type="primary" @click="handleCreate">
        <template #icon>
          <PlusOutlined />
        </template>
        新建任务
      </a-button>
    </div>

    <!-- 筛选条件 -->
    <a-card :bordered="false" style="margin-bottom: 16px">
      <a-form layout="inline" :model="filters">
        <a-form-item label="状态">
          <a-select
            v-model:value="filters.status"
            placeholder="选择状态"
            style="width: 150px"
            allow-clear
          >
            <a-select-option value="pending">待执行</a-select-option>
            <a-select-option value="running">执行中</a-select-option>
            <a-select-option value="completed">已完成</a-select-option>
            <a-select-option value="failed">失败</a-select-option>
          </a-select>
        </a-form-item>
        <a-form-item>
          <a-button type="primary" @click="handleSearch">查询</a-button>
          <a-button style="margin-left: 8px" @click="handleReset">重置</a-button>
        </a-form-item>
      </a-form>
    </a-card>

    <!-- 任务列表表格 -->
    <a-table
      :columns="columns"
      :data-source="tasks"
      :loading="loading"
      :pagination="pagination"
      @change="handleTableChange"
      row-key="task_id"
    >
      <template #bodyCell="{ column, record }">
        <template v-if="column.key === 'status'">
          <a-tag :color="getStatusColor(record.status)">
            {{ getStatusText(record.status) }}
          </a-tag>
        </template>
        <template v-else-if="column.key === 'target_type'">
          <a-tag>{{ getTargetTypeText(record.target_type) }}</a-tag>
        </template>
        <template v-else-if="column.key === 'action'">
          <a-space>
            <a-button
              v-if="record.status === 'pending' || record.status === 'completed' || record.status === 'failed'"
              type="link"
              @click="handleRun(record)"
            >
              执行
            </a-button>
            <a-button type="link" @click="handleViewDetail(record)">查看</a-button>
          </a-space>
        </template>
      </template>
    </a-table>

    <!-- 创建任务对话框 -->
    <TaskModal
      v-model:visible="modalVisible"
      @success="handleModalSuccess"
    />
  </div>
</template>

<script setup lang="ts">
import { ref, reactive, onMounted } from 'vue'
import { PlusOutlined } from '@ant-design/icons-vue'
import { tasksApi } from '@/api/tasks'
import type { ScanTask } from '@/api/types'
import TaskModal from './components/TaskModal.vue'

const loading = ref(false)
const tasks = ref<ScanTask[]>([])
const filters = reactive({
  status: undefined as string | undefined,
})
const modalVisible = ref(false)

const pagination = reactive({
  current: 1,
  pageSize: 20,
  total: 0,
  showSizeChanger: true,
  showTotal: (total: number) => `共 ${total} 条`,
})

const columns = [
  {
    title: '任务ID',
    dataIndex: 'task_id',
    key: 'task_id',
    width: 280,
  },
  {
    title: '任务名称',
    dataIndex: 'name',
    key: 'name',
    width: 200,
  },
  {
    title: '类型',
    dataIndex: 'type',
    key: 'type',
    width: 100,
    customRender: ({ record }: { record: ScanTask }) => {
      return record.type === 'manual' ? '手动' : '定时'
    },
  },
  {
    title: '目标类型',
    key: 'target_type',
    width: 120,
  },
  {
    title: '策略ID',
    dataIndex: 'policy_id',
    key: 'policy_id',
    width: 200,
  },
  {
    title: '状态',
    key: 'status',
    width: 100,
  },
  {
    title: '创建时间',
    dataIndex: 'created_at',
    key: 'created_at',
    width: 180,
  },
  {
    title: '执行时间',
    dataIndex: 'executed_at',
    key: 'executed_at',
    width: 180,
  },
  {
    title: '操作',
    key: 'action',
    width: 150,
    fixed: 'right' as const,
  },
]

const loadTasks = async () => {
  loading.value = true
  try {
    const response = await tasksApi.list({
      page: pagination.current,
      page_size: pagination.pageSize,
      status: filters.status,
    })
    tasks.value = response.items
    pagination.total = response.total
  } catch (error) {
    console.error('加载任务列表失败:', error)
  } finally {
    loading.value = false
  }
}

const handleSearch = () => {
  pagination.current = 1
  loadTasks()
}

const handleReset = () => {
  filters.status = undefined
  pagination.current = 1
  loadTasks()
}

const handleCreate = () => {
  modalVisible.value = true
}

const handleRun = async (record: ScanTask) => {
  try {
    await tasksApi.run(record.task_id)
    loadTasks()
  } catch (error) {
    console.error('执行任务失败:', error)
  }
}

const handleViewDetail = (record: ScanTask) => {
  // TODO: 实现任务详情页面
  console.log('查看任务详情:', record)
}

const handleModalSuccess = () => {
  modalVisible.value = false
  loadTasks()
}

const handleTableChange = (pag: any) => {
  pagination.current = pag.current
  pagination.pageSize = pag.pageSize
  loadTasks()
}

const getStatusColor = (status: string) => {
  const colors: Record<string, string> = {
    pending: 'default',
    running: 'processing',
    completed: 'success',
    failed: 'error',
  }
  return colors[status] || 'default'
}

const getStatusText = (status: string) => {
  const texts: Record<string, string> = {
    pending: '待执行',
    running: '执行中',
    completed: '已完成',
    failed: '失败',
  }
  return texts[status] || status
}

const getTargetTypeText = (type: string) => {
  const texts: Record<string, string> = {
    all: '全部主机',
    host_ids: '指定主机',
    os_family: '按OS筛选',
  }
  return texts[type] || type
}

onMounted(() => {
  loadTasks()
})
</script>

<style scoped>
.tasks-page {
  width: 100%;
}

.page-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 16px;
}

.page-header h2 {
  margin: 0;
}
</style>
