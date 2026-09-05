import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import { flushPromises, mount } from "@vue/test-utils";
import { reactive } from "vue";
const { get, post } = vi.hoisted(() => ({ get: vi.fn(), post: vi.fn() }));
vi.mock("../api/client", () => ({ api: { get, form: post }, mediaUrl: p => p }));
const route = reactive({ params: { id: "1" } });
vi.mock("vue-router", () => ({ useRoute: () => route }));
import GrowthJournalView from "./GrowthJournalView.vue";
const records = [
  { id: 1, recorded_on: "2026-09-05", created_at: "2026-09-05T02:00:00Z", author_role: "teacher", note: "主动分享积木", positive_tags: ["主动", "分享"], media: [] },
  { id: 2, recorded_on: "2026-09-04", created_at: "2026-09-04T10:00:00Z", author_role: "parent", note: "独立收拾绘本", positive_tags: ["独立"], media: [] },
];
let wrapper;
beforeEach(() => {
  route.params.id = "1";
  get.mockReset().mockImplementation(path => Promise.resolve(path.startsWith("/growth_records") ? { records, summary: { period: "近14天", record_count: 2, positive_tags: ["主动", "独立"] } } : path === "/students" ? [{ id: 1, first_name: "小满" }] : { id: Number(path.split("/").at(-1)), first_name: "小满" }));
  post.mockReset();
  HTMLDialogElement.prototype.showModal = function () { this.setAttribute("open", ""); };
  HTMLDialogElement.prototype.close = function () { this.removeAttribute("open"); };
  URL.createObjectURL = vi.fn(() => "blob:test");
  URL.revokeObjectURL = vi.fn();
  Element.prototype.scrollIntoView = vi.fn();
});
afterEach(() => { wrapper?.unmount(); wrapper = null; vi.restoreAllMocks(); });
async function setup() { wrapper = mount(GrowthJournalView, { props: { role: "teacher" }, global: { stubs: { RouterLink: { template: '<a><slot /></a>' } } } }); await flushPromises(); }
describe("growth journal workflow", () => {
  it("filters by author and dates, and reports invalid ranges", async () => {
    await setup();
    await wrapper.get('[aria-label="记录来源"]').setValue("parent");
    expect(wrapper.findAll(".record-item")).toHaveLength(1);
    expect(wrapper.get(".record-note").text()).toBe("独立收拾绘本");
    await wrapper.get('[aria-label="开始日期"]').setValue("2026-09-05");
    expect(wrapper.findAll(".record-item")).toHaveLength(0);
    await wrapper.get('[aria-label="结束日期"]').setValue("2026-09-04");
    expect(wrapper.text()).toContain("开始日期不能晚于结束日期");
  });
  it("traces keywords to the matching original observations", async () => {
    await setup();
    await wrapper.findAll(".summary-tags button")[1].trigger("click");
    expect(wrapper.findAll(".record-item")).toHaveLength(1);
    expect(wrapper.get(".record-note").text()).toBe("独立收拾绘本");
    expect(wrapper.text()).toContain("当前不参与自动分析");
    expect(wrapper.text()).not.toContain("状态良好");
  });
  it("uploads the selected file and date with the parent/teacher identity", async () => {
    await setup();
    await wrapper.get("#growth-note").setValue("  今天搭积木  ");
    await wrapper.get("#growth-date").setValue("2026-09-03");
    const file = new File(["image"], "blocks.png", { type: "image/png" });
    Object.defineProperty(wrapper.get('[type="file"]').element, "files", { value: [file], configurable: true });
    await wrapper.get('[type="file"]').trigger("change");
    expect(wrapper.findAll(".selected-files li")).toHaveLength(1);
    post.mockResolvedValue({ ...records[0], id: 3 });
    await wrapper.get("dialog form").trigger("submit"); await flushPromises();
    expect(post).toHaveBeenCalledTimes(1);
    const [url, payload, role] = post.mock.calls[0];
    expect(url).toBe("/growth_records?student_id=1"); expect(role).toBe("teacher");
    expect(payload.get("note")).toBe("今天搭积木");
    expect(payload.get("recorded_on")).toBe("2026-09-03");
    expect(payload.getAll("media[]")[0].name).toBe("blocks.png");
    expect(wrapper.text()).toContain("成长记录已保存");
    expect(URL.revokeObjectURL).toHaveBeenCalledWith("blob:test");
  });
  it("rejects empty submissions and oversized media before upload", async () => {
    await setup(); await wrapper.get("dialog form").trigger("submit");
    expect(post).not.toHaveBeenCalled();
    const file = new File(["x"], "large.mp4", { type: "video/mp4" });
    Object.defineProperty(file, "size", { value: 101 * 1024 * 1024 });
    Object.defineProperty(wrapper.get('[type="file"]').element, "files", { value: [file], configurable: true });
    await wrapper.get('[type="file"]').trigger("change");
    expect(wrapper.text()).toContain("每个文件不能超过 100 MB");
    expect(wrapper.findAll(".selected-files li")).toHaveLength(0);
  });
  it("retains the note on failed save and shows a retryable error", async () => {
    await setup(); await wrapper.get("#growth-note").setValue("待保存观察");
    post.mockRejectedValue(new Error("网络暂时不可用"));
    await wrapper.get("dialog form").trigger("submit"); await flushPromises();
    expect(wrapper.get("#growth-note").element.value).toBe("待保存观察");
    expect(wrapper.text()).toContain("网络暂时不可用");
  });
  it("ignores an obsolete child response after route changes", async () => {
    let finishOld;
    get.mockImplementation(path => path === "/growth_records?student_id=1" ? new Promise(resolve => { finishOld = resolve; }) : Promise.resolve(path.startsWith("/growth_records") ? { records: [], summary: null } : path === "/students" ? [] : { first_name: "新孩子" }));
    await setup(); route.params.id = "2"; await flushPromises();
    finishOld({ records, summary: null }); await flushPromises();
    expect(wrapper.findAll(".record-item")).toHaveLength(0);
    expect(wrapper.text()).toContain("新孩子的成长记录");
  });
});
