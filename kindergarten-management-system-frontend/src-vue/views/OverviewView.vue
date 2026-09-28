<script setup>
  import {
    computed,
    onMounted,
    ref
  } from "vue";
  import {
    ArrowRight,
    CalendarCheck,
    GraduationCap,
    Users,
    Sprout
  } from "lucide-vue-next";
  import MetricCard from "../components/MetricCard.vue";
  import StateSkeleton from "../components/StateSkeleton.vue";
  import {
    useAdminStore
  } from "../stores/admin";
  import {
    useTeacherStore
  } from "../stores/teacher";
  import {
    useParentStore
  } from "../stores/parent";
  const props = defineProps({
    role: {
      type: String,
      default: "admin"
    }
  });
  const admin = useAdminStore(),
    teacher = useTeacherStore(),
    parent = useParentStore();
  const summary = ref(null),
    children = ref([]),
    loading = ref(true),
    error = ref("");
  const isParent = computed(() => props.role === "parent");
  const title = computed(() => isParent.value ? "陪伴，从了解今天开始" : props.role === "teacher" ? "班级概览" : "园所概览");
  const metrics = computed(() => props.role === "admin" ? [
    ["教师", summary.value?.teacher_count ?? 0, "已登记", Users],
    ["班级", summary.value?.classroom_count ?? 0, "已登记", GraduationCap],
    ["学生", summary.value?.student_count ?? 0, "成长档案", Users],
    ["今日出勤", summary.value?.attendance_today?.present ?? 0, "已签到", CalendarCheck]
  ] : [
    ["本班学生", children.value.length, "已登记", Users],
    ["今日出勤", summary.value?.present ?? 0, "已签到", CalendarCheck]
  ]);
  const base = computed(() => isParent.value ? "/parent_dashboard/my_kids" : "/dashboard/kids_list");

  function name(child) {
    return [child.first_name, child.second_name, child.surname].filter(Boolean).join(" ");
  }
  async function load() {
    loading.value = true;
    error.value = "";
    try {
      if (props.role === "admin") {
        summary.value = await admin.loadSummary();
      } else if (props.role === "teacher") {
        const data = await teacher.loadWorkspace();
        children.value = data.students;
        const now = new Date();
        const today = [now.getFullYear(), String(now.getMonth() + 1).padStart(2, "0"), String(now.getDate()).padStart(2, "0")].join("-");
        summary.value = {
          present: data.attendances.filter(a => a.status === "Present" && a.date === today).length
        };
      } else {
        const data = await parent.loadFamily();
        children.value = data.profile?.students || [];
      }
    } catch (cause) {
      error.value = cause.message || "加载失败，请重试。";
    } finally {
      loading.value = false;
    }
  }
  onMounted(load);
</script>
<template>
  <div>
    <div class="page-heading">
      <div>
        <h1>{{title}}</h1>
        <p>{{isParent?'在家和在园的日常，都在孩子的成长记录里。':'查看已登记的信息，继续今天的工作。'}}</p>
      </div>
      <RouterLink class="button button-light" :to="props.role==='admin'?'/admin_dashboard/students':base">{{props.role==='admin'?'查看学生':isParent?'管理孩子':'全部学生'}}
        <ArrowRight :size="15" />
      </RouterLink>
    </div>
    <div v-if="error" class="notice error">{{error}} <button class="row-action" @click="load">重试</button></div>
    <div v-else-if="loading" class="metric-grid">
      <StateSkeleton v-for="i in 2" :key="i" :count="1" height="130px" />
    </div>
    <template v-else>
      <div v-if="!isParent" class="metric-grid overview-metrics">
        <MetricCard v-for="[label,value,foot,icon] in metrics" :key="label" :label="label" :value="value" :foot="foot" :icon="icon" />
      </div>
      <section v-if="props.role!=='admin'" class="children-section">
        <div class="surface-title">
          <h2>{{isParent?'我的孩子':'孩子的成长记录'}}</h2><span>{{children.length}} 位孩子</span>
        </div>
        <div v-if="!children.length" class="empty-state">
          <Sprout :size="30" /><strong>{{isParent?'还没有关联的孩子':'还没有学生档案'}}</strong><span>{{isParent?'提交孩子的学号，通过审批后就可以查看和记录。':'添加学生后，可以从这里打开成长记录。'}}</span>
          <RouterLink class="button button-light" :to="isParent?base:'/dashboard/add_kid'" style="margin-top:18px">{{isParent?'关联孩子':'添加学生'}}</RouterLink>
        </div>
        <div v-else class="children-list">
          <article v-for="child in children" :key="child.id" class="child-row"><span class="avatar">{{name(child).slice(0,1)}}</span>
            <div class="child-info">
              <h3>{{name(child)}}</h3>
              <p>{{child.classroom?.name||'班级未填写'}} · 学号 {{child.admission_number}}</p>
            </div>
            <RouterLink class="button button-primary" :to="base+'/'+child.id+'/growth'">成长记录
              <ArrowRight :size="14" />
            </RouterLink>
            <RouterLink class="row-action" :to="base+'/'+child.id">档案</RouterLink>
          </article>
        </div>
      </section>
      <section v-else class="admin-shortcuts">
        <h2>常用操作</h2>
        <RouterLink v-for="item in [['学生档案','/admin_dashboard/students'],['成长记录','/admin_dashboard/growth_records'],['考勤记录','/admin_dashboard/attendances'],['家长绑定审批','/admin_dashboard/parent_students']]" :key="item[1]" :to="item[1]"><span>{{item[0]}}</span>
          <ArrowRight :size="17" />
        </RouterLink>
      </section>
    </template>
  </div>
</template>
<style scoped>
  .overview-metrics {
    margin-bottom: 34px
  }

  .children-section {
    margin-top: 28px
  }

  .children-list {
    border-top: 1px solid var(--line)
  }

  .child-row {
    display: flex;
    align-items: center;
    gap: 15px;
    padding: 22px 0;
    border-bottom: 1px solid #edf0e6
  }

  .child-info {
    flex: 1;
    min-width: 0
  }

  .child-info h3 {
    font-size: 17px;
    font-weight: 600;
    margin: 0;
    color: var(--ink)
  }

  .child-info p {
    font-size: 12px;
    color: var(--muted-dark);
    margin: 5px 0 0
  }

  .child-row .avatar {
    width: 43px;
    height: 43px
  }

  .admin-shortcuts {
    max-width: 750px;
    margin-top: 38px
  }

  .admin-shortcuts h2 {
    font-size: 18px;
    font-weight: 550
  }

  .admin-shortcuts a {
    display: flex;
    justify-content: space-between;
    padding: 20px 0;
    border-bottom: 1px solid var(--line);
    font-size: 14px;
    color: var(--cyan)
  }

  @media(max-width:600px) {
    .child-row {
      flex-wrap: wrap;
      gap: 12px
    }

    .child-info {
      min-width: calc(100% - 65px)
    }

    .child-row .button {
      margin-left: 55px
    }
  }
</style>
