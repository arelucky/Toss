import { mount } from "@vue/test-utils";
import LoginView from "./LoginView.vue";

describe("LoginView", () => {
  it("uses a single administrator email OTP", async () => {
    const sendOtp = vi.fn().mockResolvedValue(undefined);
    const wrapper = mount(LoginView, { props: { sendOtp } });

    expect(wrapper.text()).toContain("硬币管理后台");
    expect(wrapper.text()).toContain("发送登录链接");

    await wrapper.get("input[type='email']").setValue("admin@example.com");
    await wrapper.get("form").trigger("submit");
    expect(sendOtp).toHaveBeenCalledWith("admin@example.com");
    expect(wrapper.text()).not.toMatch(/password|phone|google|apple/i);
  });

  it("shows a Chinese safe authentication failure message", async () => {
    const wrapper = mount(LoginView, { props: { sendOtp: vi.fn().mockRejectedValue(new Error("network failure")) } });
    await wrapper.get("input[type='email']").setValue("admin@example.com");
    await wrapper.get("form").trigger("submit");
    await Promise.resolve();

    expect(wrapper.text()).toContain("无法发送登录链接。");
    expect(wrapper.text()).not.toContain("network failure");
  });
});
