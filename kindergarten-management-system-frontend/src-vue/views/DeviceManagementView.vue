<script setup>
import { computed, onMounted, reactive, ref } from "vue";
import { Link2, LoaderCircle, MessageCircle, Power, RefreshCw, RotateCcw, TabletSmartphone, Unplug } from "lucide-vue-next";
import { api } from "../api/client";

const devices = ref([]);
const students = ref([]);
const classrooms = ref([]);
const loading = ref(true);
const saving = ref(false);
const error = ref("");
const notice = ref("");
const dialog = reactive({ open: false, mode: "bind", device: null, classroomId: "", studentId: "", search: "" });

const metrics = computed(() => [
  { label: "待绑定", value: devices.value.filter((item) => item.status === "pending").length, tone: "warn" },
  { label: "使用中", value: devices.value.filter((item) => item.status === "enabled").length, tone: "ok" },
  { label: "已停用", value: devices.value.filter((item) => item.status === "disabled").length, tone: "neutral" },
]);
const pendingDevices = computed(() => devices.value.filter((item) => item.status === "pending"));
const registeredDevices = computed(() => devices.value.filter((item) => item.status !== "pending"));
const filteredStudents = computed(() => {
  const classroomId = Number(dialog.classroomId);
  const search = dialog.search.trim().toLowerCase();
  return students.value.filter((student) => {
    if (classroomId && Number(student.classroom_id) !== classroomId) return false;
    const haystack = `${studentName(student)} ${student.admission_number || ""}`.toLowerCase();
    return !search || haystack.includes(search);
  });
});

function studentName(student) {
  return [student?.first_name, student?.second_name, student?.surname].filter(Boolean).join(" ") || "未命名儿童";
}

function formatTime(value) {
  if (!value) return "尚未记录";
  return new Date(value).toLocaleString("zh-CN", { month: "numeric", day: "numeric", hour: "2-digit", minute: "2-digit" });
}

function statusLabel(status) {
  return status === "enabled" ? "使用中" : status === "disabled" ? "已停用" : "待绑定";
}

async function loadDevices() {
  const data = await api.get("/admin/child_devices", "admin");
  devices.value = Array.isArray(data) ? data : [];
}

async function load() {
  loading.value = true;
  error.value = "";
  try {
    const [deviceRows, studentRows, classroomRows] = await Promise.all([
      api.get("/admin/child_devices", "admin"),
      api.get("/admin/students", "admin"),
      api.get("/admin/classrooms", "admin"),
    ]);
    devices.value = Array.isArray(deviceRows) ? deviceRows : [];
    students.value = Array.isArray(studentRows) ? studentRows : [];
    classrooms.value = Array.isArray(classroomRows) ? classroomRows : [];
  } catch (cause) {
    error.value = cause.message || "设备列表加载失败";
  } finally {
    loading.value = false;
  }
}

function openBinding(device, mode = "bind") {
  dialog.open = true;
  dialog.mode = mode;
  dialog.device = device;
  dialog.classroomId = device.classroom?.id ? String(device.classroom.id) : "";
  dialog.studentId = device.student?.id ? String(device.student.id) : "";
  dialog.search = "";
  error.value = "";
}

function openDisable(device) {
  dialog.open = true;
  dialog.mode = "disable";
  dialog.device = device;
  error.value = "";
}

function closeDialog() {
  if (saving.value) return;
  dialog.open = false;
  dialog.device = null;
}

async function confirmDialog() {
  if (saving.value || !dialog.device) return;
  if (dialog.mode !== "disable" && !dialog.studentId) {
    error.value = "请选择要绑定的儿童";
    return;
  }
  saving.value = true;
  error.value = "";
  try {
    if (dialog.mode === "disable") {
      await api.patch(`/admin/child_devices/${dialog.device.id}/disable`, {}, "admin");
      notice.value = `设备 ${dialog.device.device_id} 已停用，历史聊天仍然保留。`;
    } else {
      const target = students.value.find((student) => Number(student.id) === Number(dialog.studentId));
      await api.post("/admin/child_devices/bind", {
        device_id: dialog.device.device_id,
        student_id: Number(dialog.studentId),
      }, "admin");
      notice.value = `设备已绑定到${studentName(target)}`;
    }
    dialog.open = false;
    await loadDevices();
  } catch (cause) {
    error.value = cause.message || "设备操作失败";
  } finally {
    saving.value = false;
  }
}

async function enableDevice(device) {
  if (saving.value) return;
  saving.value = true;
  error.value = "";
  try {
    await api.patch(`/admin/child_devices/${device.id}/enable`, {}, "admin");
    notice.value = `设备 ${device.device_id} 已重新启用。`;
    await loadDevices();
  } catch (cause) {
    error.value = cause.message || "设备恢复失败";
  } finally {
    saving.value = false;
  }
}

onMounted(load);
</script>

<template>
  <div>
    <div class="page-heading">
      <div><span class="mono-label">ADMIN / DEVICES</span><h1>设备管理</h1><p>发现小智开发板，将设备安全绑定到儿童，并管理使用状态。</p></div>
      <button class="button button-dark" type="button" :disabled="loading" @click="load"><RefreshCw :size="15" />刷新</button>
    </div>

    <div v-if="notice" class="notice" style="margin-bottom:14px">{{ notice }}</div>
    <div v-if="error" class="notice error" style="margin-bottom:14px">{{ error }}</div>

    <div class="device-metrics">
      <article v-for="metric in metrics" :key="metric.label" class="device-metric" :class="metric.tone">
        <span>{{ metric.label }}</span><strong class="device-metric-value">{{ metric.value }}</strong>
      </article>
    </div>

    <div v-if="loading" class="empty-state"><LoaderCircle class="spin" :size="28" /></div>
    <template v-else>
      <section class="surface surface-pad" style="margin-top:20px">
        <div class="surface-title"><h2>待绑定设备</h2><span>{{ pendingDevices.length }} DEVICES</span></div>
        <div v-if="!pendingDevices.length" class="empty-state device-empty"><TabletSmartphone :size="26" /><strong>暂时没有待绑定设备</strong><span>开发板访问本机服务后会自动出现在这里。</span></div>
        <div v-else class="device-pending-grid">
          <article v-for="device in pendingDevices" :key="device.device_id" class="device-pending-card">
            <div class="device-icon"><TabletSmartphone :size="22" /></div>
            <div><strong>{{ device.device_id }}</strong><small>最近发现：{{ formatTime(device.last_seen_at) }}</small></div>
            <button class="button button-primary" type="button" :data-action="`bind-${device.device_id}`" @click="openBinding(device)"><Link2 :size="15" />绑定儿童</button>
          </article>
        </div>
      </section>

      <section class="surface" style="margin-top:20px">
        <div class="surface-title device-list-title"><h2>已登记设备</h2><span>{{ registeredDevices.length }} DEVICES</span></div>
        <div v-if="!registeredDevices.length" class="empty-state device-empty"><Unplug :size="26" /><strong>暂无已登记设备</strong></div>
        <div v-else class="table-wrap">
          <table class="data-table device-table">
            <thead><tr><th>设备</th><th>绑定儿童</th><th>班级</th><th>状态</th><th>最近连接</th><th>操作</th></tr></thead>
            <tbody>
              <tr v-for="device in registeredDevices" :key="device.device_id">
                <td data-label="设备"><strong>{{ device.device_id }}</strong></td>
                <td data-label="绑定儿童"><strong>{{ device.student?.name || "未绑定" }}</strong><small v-if="device.student?.admission_number">学号 {{ device.student.admission_number }}</small></td>
                <td data-label="班级">{{ device.classroom?.name || "—" }}</td>
                <td data-label="状态"><span class="status" :class="device.status === 'enabled' ? 'ok' : 'neutral'">{{ statusLabel(device.status) }}</span></td>
                <td data-label="最近连接">{{ formatTime(device.last_seen_at) }}</td>
                <td data-label="操作"><div class="row-actions">
                  <RouterLink class="row-action" :to="{ path: '/admin_dashboard/child_chat_sessions', query: { device_id: device.device_id } }"><MessageCircle :size="13" />查看聊天</RouterLink>
                  <button class="row-action" type="button" :data-action="`rebind-${device.id}`" @click="openBinding(device, 'rebind')"><RotateCcw :size="13" />重新绑定</button>
                  <button v-if="device.status === 'enabled'" class="row-action danger-text" type="button" :data-action="`disable-${device.id}`" @click="openDisable(device)"><Power :size="13" />停用</button>
                  <button v-else class="row-action" type="button" :data-action="`enable-${device.id}`" :disabled="saving" @click="enableDevice(device)"><Power :size="13" />重新启用</button>
                </div></td>
              </tr>
            </tbody>
          </table>
        </div>
      </section>
    </template>

    <div v-if="dialog.open" class="device-dialog-backdrop" @click.self="closeDialog">
      <section class="device-dialog surface" role="dialog" aria-modal="true" :aria-labelledby="'device-dialog-title'">
        <div class="surface-title"><div><h2 id="device-dialog-title">{{ dialog.mode === 'disable' ? '停用设备' : dialog.mode === 'rebind' ? '重新绑定设备' : '绑定儿童' }}</h2><span>{{ dialog.device?.device_id }}</span></div></div>
        <template v-if="dialog.mode === 'disable'">
          <p>停用后设备不能继续聊天，但现有儿童绑定和历史聊天都会保留。</p>
        </template>
        <template v-else>
          <div class="field full"><label for="device-classroom">选择班级</label><select id="device-classroom" v-model="dialog.classroomId"><option value="">全部班级</option><option v-for="classroom in classrooms" :key="classroom.id" :value="String(classroom.id)">{{ classroom.name }}</option></select></div>
          <div class="field full"><label for="device-search">查找儿童</label><input id="device-search" v-model="dialog.search" placeholder="输入姓名或学号" /></div>
          <div class="field full"><label for="device-student">选择儿童</label><select id="device-student" v-model="dialog.studentId"><option value="">请选择儿童</option><option v-for="student in filteredStudents" :key="student.id" :value="String(student.id)">{{ studentName(student) }} · {{ student.admission_number }}</option></select></div>
          <p v-if="dialog.mode === 'rebind'" class="device-dialog-hint">重新绑定会开启全新的对话上下文，旧儿童的聊天记录不会删除。</p>
        </template>
        <div class="device-dialog-actions"><button class="button button-light" type="button" :disabled="saving" @click="closeDialog">取消</button><button class="button device-dialog-confirm" :class="dialog.mode === 'disable' ? 'button-danger' : 'button-primary'" type="button" :disabled="saving" @click="confirmDialog"><LoaderCircle v-if="saving" class="spin" :size="15" />{{ saving ? '保存中…' : '确认' }}</button></div>
      </section>
    </div>
  </div>
</template>

<style scoped>
.spin { animation: spin 1s linear infinite; }
@keyframes spin { to { transform: rotate(360deg); } }
.danger-text { color: #a34b47; }
</style>
