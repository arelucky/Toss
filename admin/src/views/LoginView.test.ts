import { mount } from "@vue/test-utils";
import LoginView from "./LoginView.vue";

describe("LoginView", () => {
  it("uses a single administrator email OTP", async () => {
    const sendOtp = vi.fn().mockResolvedValue(undefined);
    const wrapper = mount(LoginView, { props: { sendOtp } });
    await wrapper.get("input[type='email']").setValue("admin@example.com");
    await wrapper.get("form").trigger("submit");
    expect(sendOtp).toHaveBeenCalledWith("admin@example.com");
    expect(wrapper.text()).not.toMatch(/password|phone|google|apple/i);
  });
});
