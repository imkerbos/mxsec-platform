<template>
  <a-modal
    v-model:visible="visible"
    :title="policy ? '编辑策略' : '新建策略'"
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
      <a-form-item label="策略ID" name="id">
        <a-input
          v-model:value="formData.id"
          :disabled="!!policy"
          placeholder="请输入策略ID"
        />
      </a-form-item>
      <a-form-item label="策略名称" name="name">
        <a-input v-model:value="formData.name" placeholder="请输入策略名称" />
      </a-form-item>
      <a-form-item label="版本" name="version">
        <a-input v-model:value="formData.version" placeholder="请输入版本号" />
      </a-form-item>
      <a-form-item label="描述" name="description">
        <a-textarea
          v-model:value="formData.description"
          :rows="3"
          placeholder="请输入策略描述"
        />
      </a-form-item>
      <a-form-item label="适用OS" name="os_family">
        <a-select
          v-model:value="formData.os_family"
          mode="multiple"
          placeholder="选择适用的操作系统"
        >
          <a-select-option value="rocky">Rocky Linux</a-select-option>
          <a-select-option value="centos">CentOS</a-select-option>
          <a-select-option value="oracle">Oracle Linux</a-select-option>
          <a-select-option value="debian">Debian</a-select-option>
        </a-select>
      </a-form-item>
      <a-form-item label="OS版本" name="os_version">
        <a-input v-model:value="formData.os_version" placeholder="例如: >=7" />
      </a-form-item>
      <a-form-item label="启用状态" name="enabled">
        <a-switch v-model:checked="formData.enabled" />
      </a-form-item>
    </a-form>
  </a-modal>
</template>

<script setup lang="ts">
import { ref, reactive, watch, computed } from 'vue'
import { policiesApi } from '@/api/policies'
import type { Policy } from '@/api/types'
import type { FormInstance } from 'ant-design-vue/es/form'

const props = defineProps<{
  visible: boolean
  policy?: Policy | null
}>()

const emit = defineEmits<{
  'update:visible': [value: boolean]
  success: []
}>()

const formRef = ref<FormInstance>()
const formData = reactive({
  id: '',
  name: '',
  version: '',
  description: '',
  os_family: [] as string[],
  os_version: '',
  enabled: true,
})

const rules = {
  id: [{ required: true, message: '请输入策略ID', trigger: 'blur' }],
  name: [{ required: true, message: '请输入策略名称', trigger: 'blur' }],
}

watch(
  () => props.visible,
  (visible) => {
    if (visible) {
      if (props.policy) {
        // 编辑模式，填充数据
        formData.id = props.policy.id
        formData.name = props.policy.name
        formData.version = props.policy.version || ''
        formData.description = props.policy.description || ''
        formData.os_family = [...props.policy.os_family]
        formData.os_version = props.policy.os_version || ''
        formData.enabled = props.policy.enabled
      } else {
        // 新建模式，重置表单
        formData.id = ''
        formData.name = ''
        formData.version = ''
        formData.description = ''
        formData.os_family = []
        formData.os_version = ''
        formData.enabled = true
      }
    }
  },
  { immediate: true }
)

const visible = computed({
  get: () => props.visible,
  set: (value) => emit('update:visible', value),
})

const handleSubmit = async () => {
  try {
    await formRef.value?.validate()
    if (props.policy) {
      // 更新策略
      await policiesApi.update(props.policy.id, {
        name: formData.name,
        version: formData.version,
        description: formData.description,
        os_family: formData.os_family,
        os_version: formData.os_version,
        enabled: formData.enabled,
      })
    } else {
      // 创建策略
      await policiesApi.create({
        id: formData.id,
        name: formData.name,
        version: formData.version,
        description: formData.description,
        os_family: formData.os_family,
        os_version: formData.os_version,
        enabled: formData.enabled,
      })
    }
    emit('success')
  } catch (error) {
    console.error('保存策略失败:', error)
  }
}

const handleCancel = () => {
  visible.value = false
}
</script>
