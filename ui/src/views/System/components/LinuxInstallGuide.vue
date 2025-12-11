<template>
  <div class="linux-install-guide">
    <!-- 支持的操作系统 -->
    <div class="section">
      <h3>支持的操作系统类型及版本</h3>
      <div class="os-list">
        <div class="os-item">
          <span class="os-badge">CentOS</span>
          <span>CentOS 6 及以上</span>
        </div>
        <div class="os-item">
          <span class="os-badge">Debian</span>
          <span>Debian 9 及以上</span>
        </div>
        <div class="os-item">
          <span class="os-badge">Ubuntu</span>
          <span>Ubuntu 12 及以上</span>
        </div>
        <div class="os-item">
          <span class="os-badge">Rocky</span>
          <span>Rocky Linux 8 及以上</span>
        </div>
      </div>
    </div>

    <!-- 安装步骤 -->
    <div class="section">
      <h3>安装步骤</h3>

      <!-- 步骤1：复制客户端安装命令 -->
      <div class="step">
        <h4>步骤1：复制客户端安装命令</h4>
        <div class="command-box">
          <code class="command">{{ installCommand }}</code>
          <a-button type="link" @click="copyCommand(installCommand)" class="copy-btn">
            <template #icon><CopyOutlined /></template>
            复制命令
          </a-button>
        </div>
        <a-button type="link" @click="showCustomCommand = !showCustomCommand" class="custom-btn">
          {{ showCustomCommand ? '隐藏' : '显示' }}自定义安装命令
        </a-button>
        <div v-if="showCustomCommand" class="custom-command-box">
          <p>如果需要自定义 Server 地址或绑定业务线，可以使用以下命令：</p>
          <div class="form-item">
            <label>选择业务线（可选）：</label>
            <a-select
              v-model:value="selectedBusinessLine"
              placeholder="请选择业务线（不选择则不绑定）"
              allow-clear
              show-search
              :filter-option="filterBusinessLineOption"
              style="width: 300px; margin-bottom: 12px;"
            >
              <a-select-option v-for="bl in businessLines" :key="bl.code" :value="bl.code">
                {{ bl.name }} ({{ bl.code }})
              </a-select-option>
            </a-select>
          </div>
          <div class="command-box">
            <code class="command">{{ customInstallCommand }}</code>
            <a-button type="link" @click="copyCommand(customInstallCommand)" class="copy-btn">
              <template #icon><CopyOutlined /></template>
              复制命令
            </a-button>
          </div>
        </div>
      </div>

      <!-- 步骤2：在目标主机上以管理员权限执行安装命令 -->
      <div class="step">
        <h4>步骤2：在目标主机上以管理员权限执行安装命令</h4>
        <p class="tip">
          <InfoCircleOutlined /> Linux 系统的管理员一般是 <code>root</code> 用户，请确保以管理员权限执行安装命令。
        </p>
      </div>

      <!-- 步骤3：检查安装是否成功 -->
      <div class="step">
        <h4>步骤3：检查安装是否成功</h4>

        <!-- 3.1 检查Agent运行状态 -->
        <div class="sub-step">
          <h5>3.1 检查 Agent 运行状态</h5>
          <p>执行以下命令检查 Agent 是否正常运行：</p>
          <div class="command-box">
            <code class="command">{{ statusCommand }}</code>
            <a-button type="link" @click="copyCommand(statusCommand)" class="copy-btn">
              <template #icon><CopyOutlined /></template>
              复制命令
            </a-button>
          </div>
          <p class="tip">
            如果输出结果中显示 <code>Active: active (running)</code> 字样，则表示安装启动成功。
          </p>
        </div>

        <!-- 3.2 检查Agent网络连通性 -->
        <div class="sub-step">
          <h5>3.2 检查 Agent 网络连通性</h5>
          <p>在确认 Agent 运行正常后，执行以下命令检查网络连通性：</p>
          <div class="command-box">
            <code class="command">{{ logCommand }}</code>
            <a-button type="link" @click="copyCommand(logCommand)" class="copy-btn">
              <template #icon><CopyOutlined /></template>
              复制命令
            </a-button>
          </div>
          <p class="tip">
            如果日志中显示 <code>get connection successfully</code> 或类似的连接成功信息，则视为网络畅通。
          </p>
        </div>

        <!-- 3.3 总结 -->
        <div class="sub-step">
          <h5>3.3 总结</h5>
          <p class="tip">
            如果"步骤一"和"步骤二"都显示预期结果，则表示 Agent 安装成功。
          </p>
        </div>
      </div>
    </div>

    <!-- 卸载方法 -->
    <div class="section">
      <h3>卸载方法</h3>
      <p>如需卸载 Agent，请以管理员权限执行以下命令：</p>
      <div class="command-box">
        <code class="command">{{ uninstallCommand }}</code>
        <a-button type="link" @click="copyCommand(uninstallCommand)" class="copy-btn">
          <template #icon><CopyOutlined /></template>
          复制命令
        </a-button>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
import { ref, computed, onMounted } from 'vue'
import { message } from 'ant-design-vue'
import { CopyOutlined, InfoCircleOutlined } from '@ant-design/icons-vue'
import { businessLinesApi, type BusinessLine } from '@/api/business-lines'

// 获取当前页面的基础 URL（用于构建安装脚本 URL）
const getBaseUrl = () => {
  // 从 window.location 获取当前页面的协议和主机
  const protocol = window.location.protocol
  const host = window.location.host
  return `${protocol}//${host}`
}

const baseUrl = getBaseUrl()
const installCommand = computed(() => {
  return `bash -c "if command -v curl > /dev/null; then curl -sS ${baseUrl}/agent/install.sh | bash; else wget -q -O - ${baseUrl}/agent/install.sh | bash; fi"`
})

const selectedBusinessLine = ref<string>('')
const businessLines = ref<BusinessLine[]>([])

const customInstallCommand = computed(() => {
  const httpServer = baseUrl.replace(/^https?:\/\//, '')
  let envVars = `BLS_SERVER_HOST=YOUR_SERVER_IP:6751 BLS_HTTP_SERVER=${httpServer}`
  
  // 如果选择了业务线，添加到环境变量
  if (selectedBusinessLine.value) {
    envVars += ` BLS_BUSINESS_LINE=${selectedBusinessLine.value}`
  }
  
  return `bash -c "${envVars} if command -v curl > /dev/null; then curl -sS ${baseUrl}/agent/install.sh | bash; else wget -q -O - ${baseUrl}/agent/install.sh | bash; fi"`
})

const statusCommand = 'systemctl status mxsec-agent'
const logCommand = 'tail -n 50 /var/log/mxsec-agent/agent.log | grep -i connection'
const uninstallCommand = computed(() => {
  return `bash -c "if command -v curl > /dev/null; then curl -sS ${baseUrl}/agent/uninstall.sh | bash; else wget -q -O - ${baseUrl}/agent/uninstall.sh | bash; fi"`
})

const showCustomCommand = ref(false)

// 加载业务线列表
const loadBusinessLines = async () => {
  try {
    const response = await businessLinesApi.list({ enabled: 'true', page_size: 1000 })
    // API 客户端已经处理了响应，直接返回 PaginatedResponse
    businessLines.value = response.items || []
  } catch (error) {
    console.error('加载业务线列表失败:', error)
  }
}

// 业务线筛选选项过滤
const filterBusinessLineOption = (input: string, option: any) => {
  const text = option.children[0].children || ''
  return text.toLowerCase().indexOf(input.toLowerCase()) >= 0
}

onMounted(() => {
  loadBusinessLines()
})

const copyCommand = async (command: string) => {
  try {
    await navigator.clipboard.writeText(command)
    message.success('命令已复制到剪贴板')
  } catch (err) {
    // 降级方案：使用传统方法
    const textArea = document.createElement('textarea')
    textArea.value = command
    textArea.style.position = 'fixed'
    textArea.style.opacity = '0'
    document.body.appendChild(textArea)
    textArea.select()
    try {
      document.execCommand('copy')
      message.success('命令已复制到剪贴板')
    } catch (e) {
      message.error('复制失败，请手动复制')
    }
    document.body.removeChild(textArea)
  }
}
</script>

<style scoped>
.linux-install-guide {
  padding: 16px 0;
}

.section {
  margin-bottom: 32px;
}

.section h3 {
  font-size: 16px;
  font-weight: 600;
  margin-bottom: 16px;
  color: #262626;
}

.step {
  margin-bottom: 24px;
  padding-left: 24px;
  border-left: 2px solid #e8e8e8;
}

.step h4 {
  font-size: 14px;
  font-weight: 600;
  margin-bottom: 12px;
  color: #595959;
}

.sub-step {
  margin-bottom: 16px;
  padding-left: 16px;
}

.sub-step h5 {
  font-size: 13px;
  font-weight: 600;
  margin-bottom: 8px;
  color: #8c8c8c;
}

.os-list {
  display: flex;
  flex-wrap: wrap;
  gap: 24px;
  margin-bottom: 16px;
}

.os-item {
  display: flex;
  align-items: center;
  gap: 8px;
}

.os-badge {
  display: inline-block;
  padding: 4px 12px;
  background: #f0f0f0;
  border-radius: 4px;
  font-size: 12px;
  font-weight: 600;
  color: #595959;
  min-width: 60px;
  text-align: center;
}

.command-box {
  display: flex;
  align-items: center;
  gap: 8px;
  padding: 12px;
  background: #f5f5f5;
  border-radius: 4px;
  margin: 12px 0;
  position: relative;
}

.command {
  flex: 1;
  font-family: 'Monaco', 'Menlo', 'Ubuntu Mono', 'Consolas', 'source-code-pro', monospace;
  font-size: 13px;
  color: #262626;
  word-break: break-all;
  white-space: pre-wrap;
}

.copy-btn {
  flex-shrink: 0;
}

.custom-btn {
  margin-top: 8px;
}

.custom-command-box {
  margin-top: 12px;
  padding: 12px;
  background: #fafafa;
  border-radius: 4px;
}

.form-item {
  margin-bottom: 12px;
}

.form-item label {
  display: block;
  margin-bottom: 8px;
  color: #595959;
  font-size: 13px;
  font-weight: 500;
}

.tip {
  margin: 8px 0;
  padding: 8px 12px;
  background: #e6f7ff;
  border-left: 3px solid #1890ff;
  border-radius: 2px;
  color: #595959;
  font-size: 13px;
}

.tip code {
  background: #fff;
  padding: 2px 6px;
  border-radius: 2px;
  font-family: 'Monaco', 'Menlo', 'Ubuntu Mono', 'Consolas', 'source-code-pro', monospace;
  font-size: 12px;
  color: #1890ff;
}

p {
  margin: 8px 0;
  color: #595959;
  font-size: 13px;
  line-height: 1.6;
}
</style>
