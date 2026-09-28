<script setup>
  import {
    computed,
    nextTick,
    onMounted,
    onUnmounted,
    ref,
    watch
  } from "vue";
  import {
    ArrowLeft,
    ArrowRight,
    CalendarDays,
    ImagePlus,
    LoaderCircle,
    Pencil,
    Plus,
    Search,
    Sprout,
    X
  } from "lucide-vue-next";
  import {
    useRoute
  } from "vue-router";
  import {
    api,
    mediaUrl
  } from "../api/client";
  const props = defineProps({
    role: {
      type: String,
      required: true
    }
  });
  const route = useRoute();
  const records = ref([]),
    summary = ref(null),
    student = ref(null),
    children = ref([]);
  const studentId = computed(() => {
    const requested = String(route.params.id || "");
    if (props.role !== "parent") return requested || String(children.value[0]?.id || "");
    const approved = children.value.find(child => String(child.id) === requested);
    return String(approved?.id || children.value[0]?.id || "");
  });
  const base = computed(() => {
    if (props.role === "admin") return "/admin_dashboard/growth_records";
    if (props.role === "parent" && route.path.startsWith("/parent_dashboard/growth_records")) return "/parent_dashboard/growth_records";
    return props.role === "parent" ? "/parent_dashboard/my_kids" : "/dashboard/kids_list";
  });
  const backPath = computed(() => props.role === "admin" ? "/admin_dashboard/students" : props.role === "parent" ? "/parent_dashboard/my_kids/" + studentId.value : base.value + "/" + studentId.value);
  const recordsEndpoint = computed(() => props.role === "admin" ? "/admin/growth_records" : "/growth_records");
  const studentEndpoint = computed(() => props.role === "admin" ? "/admin/students/" : "/students/");
  const loading = ref(true),
    saving = ref(false),
    error = ref(""),
    listError = ref(""),
    success = ref(""),
    formError = ref("");
  const search = ref(""),
    source = ref("all"),
    from = ref(""),
    to = ref(""),
    tag = ref("");
  const dialog = ref(null),
    input = ref(null),
    files = ref([]),
    editingRecord = ref(null);

  function localDate(date = new Date()) {
    return [date.getFullYear(), String(date.getMonth() + 1).padStart(2, "0"), String(date.getDate()).padStart(2, "0")].join("-");
  }
  const form = ref({
    recorded_on: localDate(),
    note: ""
  });

  function name(item) {
    return [item?.first_name, item?.second_name, item?.surname].filter(Boolean).join(" ") || "孩子";
  }
  const childName = computed(() => name(student.value));
  const filteredChildren = computed(() => children.value.filter(c => name(c).includes(search.value.trim())));
  const invalidRange = computed(() => from.value && to.value && from.value > to.value);
  const visibleRecords = computed(() => invalidRange.value ? [] : records.value.filter(r => (source.value === "all" || source.value === r.author_role) && (!from.value || r.recorded_on >= from.value) && (!to.value || r.recorded_on <= to.value) && (!tag.value || [...(r.positive_tags || []), ...(r.watch_tags || [])].includes(tag.value))).sort((a, b) => b.recorded_on.localeCompare(a.recorded_on) || String(b.created_at).localeCompare(String(a.created_at))));
  const groups = computed(() => {
    const grouped = new Map();
    visibleRecords.value.forEach(r => {
      if (!grouped.has(r.recorded_on)) grouped.set(r.recorded_on, []);
      grouped.get(r.recorded_on).push(r)
    });
    return [...grouped].map(([date, items]) => ({
      date,
      items
    }));
  });
  const tags = computed(() => [...new Set([...(summary.value?.positive_tags || []), ...(summary.value?.watch_tags || [])])]);

  function formatDate(value) {
    return new Date(value + "T12:00:00").toLocaleDateString("zh-CN", {
      year: "numeric",
      month: "long",
      day: "numeric",
      weekday: "long"
    });
  }

  function time(value) {
    return value ? new Date(value).toLocaleTimeString("zh-CN", {
      hour: "2-digit",
      minute: "2-digit"
    }) : "";
  }

  function clearFilters() {
    source.value = "all";
    from.value = "";
    to.value = "";
    tag.value = "";
  }
  let requestId = 0;
  async function load(clear = true) {
    const version = ++requestId,
      id = studentId.value;
    if (!id) {
      loading.value = false;
      return;
    }
    loading.value = true;
    error.value = "";
    if (clear) {
      records.value = [];
      summary.value = null;
      student.value = null;
    }
    try {
      const [payload, child] = await Promise.all([api.get(recordsEndpoint.value + "?student_id=" + encodeURIComponent(id), props.role), api.get(studentEndpoint.value + encodeURIComponent(id), props.role)]);
      if (version !== requestId) return;
      records.value = payload?.records || [];
      summary.value = payload?.summary || null;
      student.value = child;
    } catch (cause) {
      if (version === requestId) error.value = cause.message || "成长记录加载失败，请重试。";
    } finally {
      if (version === requestId) loading.value = false;
    }
  }
  async function loadChildren() {
    listError.value = "";
    try {
      const payload = props.role === "teacher" || props.role === "admin" ? await api.get(props.role === "admin" ? "/admin/students" : "/students", props.role) : await api.get("/parent/children", props.role);
      children.value = Array.isArray(payload) ? payload : props.role === "teacher" || props.role === "admin" ? [] : payload?.students || [];
    } catch {
      listError.value = "孩子列表暂时无法加载。";
    }
  }

  function releaseFiles() {
    files.value.forEach(item => URL.revokeObjectURL(item.url));
    files.value = [];
    if (input.value) input.value.value = "";
  }

  function resetForm() {
    releaseFiles();
    form.value = {
      recorded_on: localDate(),
      note: ""
    };
    editingRecord.value = null;
    formError.value = "";
  }

  function selectFiles(event) {
    const additions = Array.from(event.target.files || []);
    event.target.value = "";
    if (files.value.length + additions.length > 5) {
      formError.value = "每条记录最多上传 5 个文件。";
      return;
    }
    if (additions.some(f => !/^image\//.test(f.type) && !/^video\//.test(f.type))) {
      formError.value = "仅支持照片或视频文件。";
      return;
    }
    if (additions.some(f => f.size > 100 * 1024 * 1024)) {
      formError.value = "每个文件不能超过 100 MB。";
      return;
    }
    additions.forEach(file => files.value.push({
      file,
      url: URL.createObjectURL(file)
    }));
    formError.value = "";
  }

  function removeFile(index) {
    URL.revokeObjectURL(files.value[index].url);
    files.value.splice(index, 1);
  }

  function openForm(record = null) {
    formError.value = "";
    editingRecord.value = record;
    form.value = { recorded_on: record?.recorded_on || localDate(), note: record?.note || "" };
    dialog.value.showModal();
  }

  function closeForm() {
    if (!saving.value) dialog.value.close();
  }
  async function submit() {
    if (!form.value.note.trim() && !files.value.length) {
      formError.value = "请填写文字说明或添加照片、视频。";
      return;
    }
    if (!form.value.recorded_on) {
      formError.value = "请选择记录日期。";
      return;
    }
    const id = studentId.value;
    saving.value = true;
    formError.value = "";
    success.value = "";
    try {
      const payload = new FormData();
      payload.append("recorded_on", form.value.recorded_on);
      payload.append("note", form.value.note.trim());
      files.value.forEach(({
        file
      }) => payload.append("media[]", file));
      const isEditing = Boolean(editingRecord.value);
      const url = isEditing ? recordsEndpoint.value + "/" + editingRecord.value.id : recordsEndpoint.value + "?student_id=" + encodeURIComponent(id);
      const saved = await api.form(url, payload, props.role, isEditing ? "PATCH" : "POST");
      if (studentId.value !== id) return;
      records.value = isEditing ? records.value.map((record) => record.id === saved.id ? saved : record) : [saved, ...records.value];
      resetForm();
      dialog.value.close();
      clearFilters();
      success.value = isEditing ? "成长记录已更新。" : "成长记录已保存。";
      await load(false);
      if (error.value) error.value = "记录已保存，但刷新未完成。请重试刷新，无需重复提交。";
    } catch (cause) {
      formError.value = cause.message || "保存失败，内容已保留，请重试。";
    } finally {
      saving.value = false;
    }
  }
  async function showTag(value) {
    clearFilters();
    tag.value = value;
    await nextTick();
    document.getElementById("journal-records")?.scrollIntoView({
      behavior: window.matchMedia?.("(prefers-reduced-motion: reduce)").matches ? "instant" : "smooth",
      block: "start"
    });
  }
  watch(studentId, () => {
    clearFilters();
    success.value = "";
    dialog.value?.close();
    resetForm();
    load();
  }, {
    immediate: true
  });
  onMounted(loadChildren);
  onUnmounted(() => {
    requestId++;
    releaseFiles();
  });
</script>
<template>
  <div class="growth-workspace" :class="{family:role==='parent'}">
    <aside v-if="role==='teacher'||role==='admin'" class="child-selector">
      <h2>{{role==='admin'?'全园学生':'本班学生'}}</h2>
      <p>{{children.length}} 位孩子</p>
      <label class="child-search">
        <Search :size="15" /><input v-model="search" aria-label="搜索孩子" placeholder="搜索孩子姓名" />
      </label>
      <div v-if="listError" class="list-error">{{listError}} <button class="row-action" @click="loadChildren">重试</button></div>
      <nav aria-label="切换孩子">
        <RouterLink v-for="child in filteredChildren" :key="child.id" :to="base+'/'+child.id+'/growth'" :class="{selected:String(child.id)===studentId}" :aria-current="String(child.id)===studentId?'page':undefined"><span class="avatar">{{name(child).slice(0,1)}}</span><span><strong>{{name(child)}}</strong><small>{{child.classroom?.name||'学号 '+child.admission_number}}</small></span></RouterLink>
      </nav>
      <p v-if="search&&!filteredChildren.length">没有匹配的孩子</p>
    </aside>
    <main class="journal-main">
      <div class="journal-breadcrumb">
        <RouterLink :to="base">{{role==='teacher'?'本班学生':'我的孩子'}}</RouterLink><span>/</span>
        <RouterLink :to="backPath">{{student?childName:'孩子档案'}}</RouterLink><span>/ 成长记录</span>
      </div>
      <div class="page-heading">
        <div>
          <h1>{{student?childName+'的成长记录':'成长记录'}}</h1>
          <p>一起留意日常里的小小变化。</p>
        </div><button class="button button-primary" :disabled="loading||!student" @click="openForm()">
          <Plus :size="16" />新增记录
        </button>
      </div>
      <div v-if="role==='parent'&&children.length>1" class="family-switch"><label for="family-child">切换孩子</label><select id="family-child" :value="studentId" @change="$router.push(base+'/'+$event.target.value+'/growth')">
          <option v-for="child in children" :key="child.id" :value="String(child.id)">{{name(child)}}</option>
        </select></div>
      <div v-if="error" class="notice error" role="alert">{{error}} <button class="row-action" @click="load(false)">重新加载</button></div>
      <div v-if="success" class="notice" role="status">{{success}}</div>
      <div class="journal-filters"><label>从<input v-model="from" type="date" aria-label="开始日期" /></label><label>至<input v-model="to" type="date" aria-label="结束日期" /></label><select v-model="source" aria-label="记录来源">
          <option value="all">全部来源</option>
          <option value="teacher">教师记录</option>
          <option value="parent">家长记录</option>
          <option v-if="role==='admin'" value="admin">管理员记录</option>
        </select><button v-if="from||to||source!=='all'||tag" class="row-action" @click="clearFilters">清除筛选{{tag?' · '+tag:''}}</button><span>{{visibleRecords.length}} 条记录</span></div>
      <p v-if="invalidRange" class="notice error">开始日期不能晚于结束日期。</p>
      <div v-if="loading" class="empty-state" role="status">
        <LoaderCircle class="spin" :size="28" />正在加载记录…
      </div>
      <div v-else class="journal-columns">
        <section id="journal-records" class="record-timeline" aria-label="成长记录时间线" aria-live="polite">
          <div v-if="!groups.length&&!error" class="empty-state">
            <Sprout :size="32" /><strong>{{records.length?'当前筛选下没有记录':'还没有成长记录'}}</strong><span>{{records.length?'试试其他日期，或清除筛选。':'从今天的一次小观察开始吧。'}}</span><button v-if="!records.length" class="button button-light" style="margin-top:20px" :disabled="!student" @click="openForm">
              <Plus :size="15" />记下第一个瞬间
            </button>
          </div>
          <section v-for="group in groups" :key="group.date" class="day-group">
            <h2>
              <CalendarDays :size="15" />{{formatDate(group.date)}}
            </h2>
            <article v-for="record in group.items" :key="record.id" class="record-item">
              <div class="record-author"><span class="avatar">{{record.author_role==='parent'?'家':record.author_role==='admin'?'管':'师'}}</span><strong>{{record.author_role==='parent'?'家长记录':record.author_role==='admin'?'管理员记录':'教师记录'}}</strong><time>{{time(record.created_at)}} 发布</time><button v-if="role==='admin'||record.author_role===role" class="row-action" type="button" @click="openForm(record)"><Pencil :size="13" />编辑</button></div>
              <p v-if="record.note" class="record-note">{{record.note}}</p>
              <div v-if="record.media?.length" class="record-media" :class="{single:record.media.length===1}">
                <figure v-for="file in record.media" :key="file.id"><video v-if="file.content_type?.startsWith('video/')" controls playsinline preload="metadata" :src="mediaUrl(file.url)" /><a v-else :href="mediaUrl(file.url)" target="_blank" rel="noopener noreferrer" :aria-label="'查看原图：'+file.filename"><img :src="mediaUrl(file.url)" :alt="file.filename" loading="lazy" /></a>
                  <figcaption>{{file.filename}}</figcaption>
                </figure>
              </div>
              <details v-if="record.analysis" class="record-analysis">
                <summary>AI 观察摘要</summary>
                <p>{{record.analysis}}</p><small v-if="record.analysis_status==='completed'">根据本条文字、图片及视频代表帧整理，请结合原始记录理解。</small><small v-else>原始记录仍可查看，请结合文字、照片和视频理解。</small>
              </details>
              <p v-else-if="record.analysis_status==='failed'" class="analysis-unavailable">AI 分析暂时不可用，原始记录已保存。</p>
            </article>
          </section>
        </section>
        <aside v-if="summary" class="observation-summary">
          <h2>记录里的线索</h2><small>{{summary.period}} · {{summary.record_count}} 条记录</small>
          <p>{{tags.length?'AI 从文字、图片和视频画面中提取了这些线索，点击可回顾对应的原始记录。':'还没有识别到明确线索，可以继续补充日常观察。'}}</p>
          <div class="summary-tags"><button v-for="word in tags" :key="word" :aria-pressed="tag===word" @click="showTag(word)">{{word}}
              <ArrowRight :size="12" />
            </button></div>
          <p class="analysis-limit">AI 仅根据本条记录中的明确文字、图片和视频代表帧整理线索；无法确认的内容会单独说明，不会强行推断。</p>
          <RouterLink class="text-link" :to="backPath">
            <ArrowLeft :size="13" />孩子档案
          </RouterLink>
        </aside>
      </div>
    </main>
    <dialog ref="dialog" class="growth-dialog" aria-labelledby="growth-dialog-title" @cancel.prevent="closeForm">
      <div class="dialog-heading">
        <div>
          <h2 id="growth-dialog-title">{{editingRecord?'编辑成长记录':'新增成长记录'}}</h2>
          <p>{{childName}} · {{role==='parent'?'家长记录':role==='admin'?'管理员记录':'教师记录'}}</p>
        </div><button class="icon-button" aria-label="关闭录入窗口" :disabled="saving" @click="closeForm">
          <X :size="18" />
        </button>
      </div>
      <form @submit.prevent="submit">
        <div v-if="formError" class="notice error" role="alert">{{formError}}</div><label for="growth-date">记录日期</label><input id="growth-date" v-model="form.recorded_on" type="date" required :disabled="saving" /><label for="growth-note">发生了什么？</label><textarea id="growth-note" v-model="form.note" rows="5" :disabled="saving" placeholder="写下孩子说了什么、做了什么，也可以只添加照片或视频。" />
        <div class="file-toolbar"><button class="button button-light" type="button" :disabled="saving||files.length>=5" @click="input.click()">
            <ImagePlus :size="16" />添加照片或视频
          </button><small>{{files.length}} / 5 · 每个不超过 100 MB · 保存后由 AI 分析文字、图片和视频画面</small></div><input ref="input" class="file-input" type="file" accept="image/*,video/*" multiple aria-label="选择照片或视频" :disabled="saving" @change="selectFiles" />
        <ul v-if="files.length" class="selected-files">
          <li v-for="(item,index) in files" :key="item.url"><video v-if="item.file.type.startsWith('video/')" :src="item.url" controls preload="metadata" /><img v-else :src="item.url" :alt="item.file.name" /><span>{{item.file.name}}</span><button type="button" :aria-label="'移除 '+item.file.name" :disabled="saving" @click="removeFile(index)">
              <X :size="14" />
            </button></li>
        </ul>
        <footer><small>关闭窗口会暂时保留本次输入。</small><button class="button button-primary" :disabled="saving" type="submit">
            <LoaderCircle v-if="saving" class="spin" :size="16" />{{saving?'正在保存…':editingRecord?'保存修改':'保存成长记录'}}
          </button></footer>
      </form>
    </dialog>
  </div>
</template>
<style scoped>
  .growth-workspace {
    display: grid;
    grid-template-columns: 195px minmax(0, 1fr);
    gap: 30px
  }

  .growth-workspace.family {
    grid-template-columns: 1fr
  }

  .child-selector {
    border-right: 1px solid var(--line);
    padding-right: 18px;
    min-width: 0
  }

  .child-selector h2 {
    font-size: 17px;
    font-weight: 600;
    margin: 0
  }

  .child-selector p {
    font-size: 12px;
    color: var(--muted-dark);
    margin: 6px 0 20px
  }

  .child-search {
    display: flex;
    align-items: center;
    gap: 7px;
    padding: 8px;
    border: 1px solid var(--line);
    border-radius: 7px;
    color: #758569;
    margin-bottom: 18px
  }

  .child-search input {
    border: 0;
    min-width: 0;
    width: 100%;
    font-size: 12px;
    background: transparent
  }

  .child-selector nav {
    display: grid;
    gap: 4px
  }

  .child-selector nav a {
    display: flex;
    align-items: center;
    gap: 9px;
    border-radius: 8px;
    padding: 12px 8px
  }

  .child-selector nav a.selected {
    background: #eaf0e1
  }

  .child-selector strong {
    display: block;
    font-size: 13px;
    font-weight: 600;
    overflow-wrap: anywhere
  }

  .child-selector small {
    display: block;
    font-size: 10px;
    color: var(--muted-dark);
    margin-top: 2px
  }

  .journal-main {
    min-width: 0
  }

  .journal-breadcrumb {
    display: flex;
    gap: 9px;
    flex-wrap: wrap;
    color: #77876a;
    font-size: 12px;
    margin-bottom: 22px
  }

  .journal-breadcrumb a:hover {
    text-decoration: underline
  }

  .journal-main .page-heading h1 {
    font-size: 27px
  }

  .journal-main .notice {
    margin-bottom: 15px
  }

  .journal-filters {
    display: flex;
    align-items: center;
    flex-wrap: wrap;
    gap: 9px;
    border-bottom: 1px solid var(--line);
    padding-bottom: 20px;
    margin-bottom: 24px
  }

  .journal-filters label {
    font-size: 12px;
    color: #7b886f;
    display: flex;
    align-items: center;
    gap: 6px
  }

  .journal-filters input,
  .journal-filters select,
  .family-switch select {
    font-size: 12px;
    padding: 7px 9px;
    border: 1px solid var(--line);
    background: #fff;
    border-radius: 6px;
    color: #516244;
    min-width: 0
  }

  .journal-filters>span {
    font-size: 12px;
    color: #7b886f;
    margin-left: auto
  }

  .family-switch {
    display: flex;
    gap: 10px;
    align-items: center;
    font-size: 13px;
    margin-bottom: 20px
  }

  .journal-columns {
    display: grid;
    grid-template-columns: minmax(0, 1fr) 185px;
    gap: 28px
  }

  .record-timeline {
    min-width: 0;
    scroll-margin-top: 25px
  }

  .day-group h2 {
    display: flex;
    gap: 8px;
    align-items: center;
    margin: 0 0 20px;
    font-size: 13px;
    font-weight: 550;
    color: #697d59
  }

  .record-item {
    padding-bottom: 24px;
    margin-bottom: 24px;
    border-bottom: 1px solid #e9eee1
  }

  .record-author {
    display: flex;
    align-items: center;
    gap: 8px;
    font-size: 12px;
    color: #6b7a5f
  }

  .record-author strong {
    font-weight: 500
  }

  .record-author time {
    font-size: 11px;
    color: #818e74
  }

  .record-author .avatar {
    width: 27px;
    height: 27px;
    font-size: 10px;
    background: #edf1e4;
    color: #748467
  }

  .record-note {
    font-size: 15px;
    color: #48573c;
    line-height: 1.9;
    margin: 15px 0;
    white-space: pre-wrap;
    overflow-wrap: anywhere
  }

  .record-media {
    display: grid;
    grid-template-columns: repeat(2, minmax(0, 1fr));
    gap: 12px;
    margin-top: 15px
  }

  .record-media.single {
    grid-template-columns: 1fr
  }

  .record-media figure {
    margin: 0;
    min-width: 0
  }

  .record-media img,
  .record-media video {
    display: block;
    width: 100%;
    height: auto;
    max-height: 370px;
    object-fit: contain;
    border-radius: 8px;
    background: #f1f2eb
  }

  .record-media figcaption {
    font-size: 10px;
    color: #849478;
    white-space: nowrap;
    overflow: hidden;
    text-overflow: ellipsis;
    margin-top: 5px
  }

  .record-analysis {
    font-size: 12px;
    color: #7b8b6e;
    margin-top: 17px
  }

  .record-analysis summary {
    cursor: pointer
  }

  .record-analysis p {
    line-height: 1.8
  }

  .record-analysis small {
    font-size: 11px
  }

  .observation-summary {
    border-left: 1px solid var(--line);
    padding-left: 19px;
    align-self: start
  }

  .observation-summary h2 {
    font-size: 14px;
    font-weight: 600;
    margin: 0 0 3px
  }

  .observation-summary>small {
    font-size: 11px;
    color: #7e8b72
  }

  .observation-summary p {
    font-size: 12px;
    color: #74846a;
    line-height: 1.85;
    margin: 17px 0
  }

  .summary-tags {
    display: flex;
    flex-wrap: wrap;
    gap: 7px
  }

  .summary-tags button {
    display: flex;
    align-items: center;
    gap: 5px;
    border: 1px solid #e2e9d7;
    background: #f3f6ed;
    color: #607951;
    border-radius: 6px;
    padding: 5px 8px;
    font-size: 12px
  }

  .summary-tags button[aria-pressed=true] {
    background: #dce9cd;
    border-color: #94ad7d
  }

  .analysis-limit {
    border-top: 1px solid var(--line);
    padding-top: 15px;
    font-size: 11px !important
  }

  .observation-summary .text-link {
    font-size: 12px;
    display: flex;
    align-items: center;
    gap: 7px
  }

  .list-error {
    font-size: 12px;
    color: #956245
  }

  .growth-dialog {
    width: min(590px, calc(100vw - 30px));
    max-height: 90dvh;
    overflow: auto;
    padding: 28px;
    border: 1px solid var(--line);
    border-radius: 14px;
    box-shadow: 0 24px 80px #24371833;
    color: var(--ink)
  }

  .growth-dialog::backdrop {
    background: #20351255;
    backdrop-filter: blur(3px)
  }

  .dialog-heading {
    display: flex;
    justify-content: space-between;
    gap: 20px;
    margin-bottom: 20px
  }

  .dialog-heading h2 {
    font-size: 22px;
    font-weight: 600;
    margin: 0
  }

  .dialog-heading p {
    font-size: 13px;
    color: var(--muted-dark);
    margin: 6px 0
  }

  .growth-dialog form>label {
    display: block;
    margin: 18px 0 7px;
    font-size: 13px;
    color: #637653
  }

  .growth-dialog input:not([type=file]),
  .growth-dialog textarea {
    width: 100%;
    border: 1px solid var(--line);
    border-radius: 7px;
    padding: 10px 12px;
    color: var(--ink);
    background: #fff;
    font-size: 14px;
    resize: vertical
  }

  .file-toolbar {
    display: flex;
    align-items: center;
    flex-wrap: wrap;
    gap: 10px;
    margin-top: 18px
  }

  .file-toolbar small {
    font-size: 11px;
    color: #7f8d72
  }

  .file-input {
    display: none
  }

  .selected-files {
    list-style: none;
    padding: 0;
    display: grid;
    grid-template-columns: repeat(3, minmax(0, 1fr));
    gap: 10px
  }

  .selected-files li {
    position: relative;
    min-width: 0
  }

  .selected-files img,
  .selected-files video {
    width: 100%;
    height: 85px;
    object-fit: contain;
    border-radius: 6px;
    background: #eef2e6
  }

  .selected-files span {
    display: block;
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
    font-size: 10px;
    color: #7b8a6f
  }

  .selected-files button {
    position: absolute;
    right: 3px;
    top: 3px;
    border: 1px solid var(--line);
    background: #fff;
    border-radius: 50%;
    width: 26px;
    height: 26px;
    display: grid;
    place-items: center
  }

  .growth-dialog footer {
    display: flex;
    align-items: center;
    justify-content: space-between;
    gap: 15px;
    margin-top: 26px;
    border-top: 1px solid var(--line);
    padding-top: 18px
  }

  .growth-dialog footer small {
    font-size: 11px;
    color: #7b8a6d
  }

  .spin {
    animation: spin 1s linear infinite
  }

  @keyframes spin {
    to {
      transform: rotate(360deg)
    }
  }

  @media(max-width:1250px) {
    .journal-columns {
      grid-template-columns: 1fr
    }

    .observation-summary {
      border-left: 0;
      border-top: 1px solid var(--line);
      padding: 22px 0 0
    }

    .growth-workspace {
      grid-template-columns: 170px minmax(0, 1fr);
      gap: 22px
    }
  }

  @media(max-width:980px) {
    .growth-workspace {
      grid-template-columns: 1fr
    }

    .child-selector {
      border-right: 0;
      border-bottom: 1px solid var(--line);
      padding: 0 0 16px
    }

    .child-selector nav {
      display: flex;
      overflow-x: auto
    }

    .child-selector nav a {
      min-width: 140px
    }

    .child-selector p {
      margin-bottom: 12px
    }

    .child-search {
      max-width: 280px;
      margin-bottom: 10px
    }

    .journal-main .page-heading h1 {
      font-size: 25px
    }
  }

  @media(max-width:600px) {
    .journal-filters {
      align-items: flex-start
    }

    .journal-filters input {
      max-width: 140px
    }

    .growth-dialog {
      padding: 20px
    }

    .growth-dialog footer {
      flex-direction: column;
      align-items: stretch
    }

    .record-media {
      gap: 8px
    }

    .record-note {
      font-size: 15px
    }

    .selected-files {
      grid-template-columns: repeat(2, minmax(0, 1fr))
    }
  }
</style>
