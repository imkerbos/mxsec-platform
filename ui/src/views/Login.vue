<template>
  <div class="login-container">
    <!-- 左侧装饰区域 -->
    <div class="login-left">
      <div class="decorative-shapes">
        <!-- 抽象几何图形装饰 -->
        <div class="shape shape-1"></div>
        <div class="shape shape-2"></div>
        <div class="shape shape-3"></div>
        <div class="shape shape-4"></div>
        <div class="shape shape-5"></div>
        <div class="shape shape-6"></div>
      </div>
    </div>

    <!-- 右侧登录表单区域 -->
    <div class="login-right">
      <div class="login-content">
        <div class="login-header">
          <h1>登录 矩阵云安全平台</h1>
        </div>

        <a-form
          :model="form"
          :rules="rules"
          @finish="handleLogin"
          class="login-form"
          layout="vertical"
        >
          <a-form-item name="username">
            <a-input
              v-model:value="form.username"
              size="large"
              placeholder="用户名"
              :prefix="h(UserOutlined)"
              class="login-input"
            />
          </a-form-item>
          <a-form-item name="password">
            <a-input-password
              v-model:value="form.password"
              size="large"
              placeholder="密码"
              :prefix="h(LockOutlined)"
              @pressEnter="handleLogin"
              class="login-input"
            />
          </a-form-item>
          <a-form-item>
            <a-button
              type="primary"
              html-type="submit"
              size="large"
              block
              :loading="loading"
              class="login-button"
            >
              登录
            </a-button>
          </a-form-item>
        </a-form>

        <div v-if="error" class="error-message">
          <a-alert :message="error" type="error" show-icon />
        </div>
      </div>

      <!-- 页脚 -->
      <div class="login-footer">
        矩阵云安全平台
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
import { ref, reactive, h } from 'vue'
import { useRouter } from 'vue-router'
import { UserOutlined, LockOutlined } from '@ant-design/icons-vue'
import { useAuthStore } from '@/stores/auth'
import type { Rule } from 'ant-design-vue/es/form'

const router = useRouter()
const authStore = useAuthStore()

const loading = ref(false)
const error = ref('')

const form = reactive({
  username: '',
  password: '',
})

const rules: Record<string, Rule[]> = {
  username: [{ required: true, message: '请输入用户名', trigger: 'blur' }],
  password: [{ required: true, message: '请输入密码', trigger: 'blur' }],
}

const handleLogin = async () => {
  error.value = ''
  loading.value = true
  try {
    await authStore.login({
      username: form.username,
      password: form.password,
    })
    router.push('/')
  } catch (err: any) {
    error.value = err.message || '登录失败，请检查用户名和密码'
  } finally {
    loading.value = false
  }
}
</script>

<style scoped>
.login-container {
  display: flex;
  min-height: 100vh;
  width: 100%;
}

/* 左侧装饰区域 */
.login-left {
  flex: 0 0 35%;
  position: relative;
  background: linear-gradient(135deg, #1e3c72 0%, #2a5298 50%, #7e57c2 100%);
  overflow: hidden;
  display: flex;
  align-items: center;
  justify-content: center;
}

.decorative-shapes {
  position: relative;
  width: 100%;
  height: 100%;
}

.shape {
  position: absolute;
  border-radius: 50%;
  opacity: 0.6;
  animation: float 6s ease-in-out infinite;
}

.shape-1 {
  width: 120px;
  height: 120px;
  background: linear-gradient(135deg, #ff6b9d 0%, #ff8fab 100%);
  top: 15%;
  left: 10%;
  animation-delay: 0s;
  border-radius: 30% 70% 70% 30% / 30% 30% 70% 70%;
}

.shape-2 {
  width: 80px;
  height: 200px;
  background: linear-gradient(135deg, #4facfe 0%, #00f2fe 100%);
  top: 25%;
  right: 15%;
  animation-delay: 1s;
  border-radius: 50%;
}

.shape-3 {
  width: 150px;
  height: 150px;
  background: linear-gradient(135deg, #a8edea 0%, #fed6e3 100%);
  bottom: 20%;
  left: 20%;
  animation-delay: 2s;
  border-radius: 40% 60% 60% 40% / 60% 30% 70% 40%;
}

.shape-4 {
  width: 100px;
  height: 100px;
  background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
  top: 50%;
  right: 25%;
  animation-delay: 1.5s;
  border-radius: 50%;
}

.shape-5 {
  width: 60px;
  height: 60px;
  background: rgba(255, 255, 255, 0.3);
  top: 10%;
  left: 50%;
  animation-delay: 0.5s;
  border-radius: 50%;
  backdrop-filter: blur(10px);
}

.shape-6 {
  width: 200px;
  height: 4px;
  background: linear-gradient(90deg, transparent 0%, rgba(255, 255, 255, 0.5) 50%, transparent 100%);
  top: 60%;
  left: 5%;
  animation-delay: 2.5s;
  transform: rotate(45deg);
}

@keyframes float {
  0%, 100% {
    transform: translateY(0px) rotate(0deg);
  }
  50% {
    transform: translateY(-20px) rotate(5deg);
  }
}

/* 右侧登录表单区域 */
.login-right {
  flex: 1;
  display: flex;
  flex-direction: column;
  justify-content: center;
  align-items: center;
  background: #ffffff;
  padding: 40px;
  position: relative;
}

.login-content {
  width: 100%;
  max-width: 420px;
}

.login-header {
  text-align: center;
  margin-bottom: 48px;
}

.login-header h1 {
  margin: 0;
  font-size: 28px;
  font-weight: 600;
  color: #001529;
  letter-spacing: 0.5px;
}

.login-form {
  margin-bottom: 24px;
}

.login-input {
  height: 48px;
  border-radius: 6px;
}

.login-input :deep(.ant-input) {
  font-size: 15px;
}

.login-input :deep(.anticon) {
  color: #8c8c8c;
  font-size: 16px;
}

.login-button {
  height: 48px;
  border-radius: 6px;
  font-size: 16px;
  font-weight: 500;
  margin-top: 8px;
}

.error-message {
  margin-top: 16px;
}

/* 页脚 */
.login-footer {
  position: absolute;
  bottom: 24px;
  left: 50%;
  transform: translateX(-50%);
  font-size: 14px;
  color: #8c8c8c;
  text-align: center;
}

/* 响应式设计 */
@media (max-width: 768px) {
  .login-container {
    flex-direction: column;
  }

  .login-left {
    flex: 0 0 200px;
    min-height: 200px;
  }

  .login-right {
    flex: 1;
    padding: 24px;
  }

  .login-content {
    max-width: 100%;
  }
}
</style>
