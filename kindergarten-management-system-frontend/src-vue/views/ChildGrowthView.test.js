// @vitest-environment jsdom
import { describe, expect, it } from "vitest";
import { mount } from "@vue/test-utils";
import ChildGrowthView from "./ChildGrowthView.vue";

describe("ChildGrowthView", () => {
  it("uses the same-origin child-growth proxy by default", () => {
    const wrapper = mount(ChildGrowthView);

    expect(wrapper.get("iframe").attributes("src")).toBe("/child-growth/");
    expect(wrapper.get("a").attributes("href")).toBe("/child-growth/");
  });
});
