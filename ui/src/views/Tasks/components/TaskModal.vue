<template>
  <a-modal
    v-model:visible="visible"
    title="新建扫描任务"
    width="800px"
    @ok="handleSubmit"
    @cancel="handleCancel"
  >
    <a-form
      ref="formRef"
      :model="formData"
      :rules="rules"
      :label-col="{ span: 6 }"
      :wrapper-col="{ span: 18 }"
    >
      <a-form-item label="任务名称" name="name">
        <a-input v-model:value="formData.name" placeholder="请输入任务名称" />
      </a-form-item>
      <a-form-item label="任务类型" name="type">
        <a-radio-group v-model:value="formData.type">
          <a-radio value="manual">手动</a-radio>
          <a-radio value="scheduled">定时</a-radio>
        </a-radio-group>
      </a-form-item>
      <a-form-item label="策略" name="policy_id">
        <a-select
          v-model:value="formData.policy_id"
          placeholder="选择策略"
          :loading="policiesLoading"
        >
          <a-select-option
            v-for="policy in policies"
            :key="policy.id"
            :value="policy.id"
          >
            {{ policy.name }} ({{ policy.id }})
          </a-select-option>
        </a-select>
      </a-form-item>
      <a-form-item label="目标类型" name="target_type">
        <a-radio-group v-model:value="formData.target_type" @change="handleTargetTypeChange">
          <a-radio value="all">全部主机</a-radio>
          <a-radio value="host_ids">指定主机</a-radio>
          <a-radio value="os_family">按OS筛选</a-radio>
        </a-radio-group>
      </a-form-item>
      <a-form-item
        v-if="formData.target_type === 'host_ids'"
        label="主机ID列表"
        name="host_ids"
      >
        <a-select
          v-model:value="formData.host_ids"
          mode="tags"
          placeholder="输入主机ID，按回车添加"
          :loading="hostsLoading"
        >
          <a-select-option
            v-for="host in hosts"
            :key="host.host_id"
            :value="host.host_id"
          >
            {{ host.hostname }} ({{ host.host_id }})
          </a-select-option>
        </a-select>
      </a-form-item>
      <a-form-item
        v-if="formData.target_type === 'os_family'"
        label="操作系统"
        name="os_family"
      >
        <a-select
          v-model:value="formData.os_family"
          mode="multiple"
          placeholder="选择操作系统"
        >
          <a-select-option value="rocky">Rocky Linux</a-select-option>
          <a-select-option value="centos">CentOS</a-select-option>
          <a-select-option value="oracle">Oracle Linux</a-select-option>
          <a-select-option value="debian">Debian</a-select-option>
        </a-select>
      </a-form-item>
    </a-form>
  </a-modal>
</template>

<script setup lang="ts">
import { ref, reactive, watch, onMounted, computed } from 'vue'
import { tasksApi } from '@/api/tasks'
import { policiesApi } from '@/api/policies'
import { hostsApi } from '@/api/hosts'
import type { Policy, Host } from '@/api/types'
import type { FormInstance } from 'ant-design-vue/es/form'

const props = defineProps<{
  visible: boolean
}>()

const emit = defineEmits<{
  'update:visible': [value: boolean]
  success: []
}>()

const formRef = ref<FormInstance>()
const policies = ref<Policy[]>([])
const hosts = ref<Host[]>([])
const policiesLoading = ref(false)
const hostsLoading = ref(false)

const formData = reactive({
  name: '',
  type: 'manual' as 'manual' | 'scheduled',
  policy_id: '',
  target_type: 'all' as 'all' | 'host_ids' | 'os_family',
  host_ids: [] as string[],
  os_family: [] as string[],
})

const rules = {
  name: [{ required: true, message: '请输入任务名称', trigger: 'blur' }],
  policy_id: [{ required: true, message: '请选择策略', trigger: 'change' }],
  host_ids: [
    {
      validator: (_rule: any, value: string[]) => {
        if (formData.target_type === 'host_ids' && (!value || value.length === 0)) {
          return Promise.reject('请至少选择一个主机')
        }
        return Promise.resolve()
      },
      trigger: 'change',
    },
  ],
  os_family: [
    {
      validator: (_rule: any, value: string[]) => {
        if (formData.target_type === 'os_family' && (!value || value.length === 0)) {
          return Promise.reject('请至少选择一个操作系统')
        }
        return Promise.resolve()
      },
      trigger: 'change',
    },
  ],
}

const visible = computed({
  get: () => props.visible,
  set: (value) => emit('update:visible', value),
})

const loadPolicies = async () => {
  policiesLoading.value = true
  try {
    const response = await policiesApi.list({ enabled: true })
    policies.value = response.items
  } catch (error) {
    console.error('加载策略列表失败:', error)
  } finally {
    policiesLoading.value = false
  }
}

const loadHosts = async () => {
  hostsLoading.value = true
  try {
    const response = await hostsApi.list({ page_size: 100 })
    hosts.value = response.items
  } catch (error) {
    console.error('加载主机列表失败:', error)
  } finally {
    hostsLoading.value = false
  }
}

const handleTargetTypeChange = () => {
  formData.host_ids = []
  formData.os_family = []
}

const handleSubmit = async () => {
  try {
    await formRef.value?.validate()
    const targets: any = {
      type: formData.target_type,
    }
    if (formData.target_type === 'host_ids') {
      targets.host_ids = formData.host_ids
    } else if (formData.target_type === 'os_family') {
      targets.os_family = formData.os_family
    }
    await tasksApi.create({
      name: formData.name,
      type: formData.type,
      targets,
      policy_id: formData.policy_id,
    })
    emit('success')
  } catch (error) {
    console.error('创建任务失败:', error)
  }
}

const handleCancel = () => {
  visible.value = false
  // 重置表单
  formData.name = ''
  formData.type = 'manual'
  formData.policy_id = ''
  formData.target_type = 'all'
  formData.host_ids = []
  formData.os_family = []
}

watch(
  () => props.visible,
  (visible) => {
    if (visible) {
      loadPolicies()
      loadHosts()
    }
  }
)

onMounted(() => {
  loadPolicies()
  loadHosts()
})
</script>
