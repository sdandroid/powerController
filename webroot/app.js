import { exec, toast } from "./kernelsu.js";

const MODULE_DIR = "/data/adb/modules/oplusPowerController";
const STATUS_COMMAND = `sh ${MODULE_DIR}/get-status.sh`;
const SET_CONFIG_COMMAND = `sh ${MODULE_DIR}/set-config.sh`;

const elements = {
  state: document.querySelector("#controller-state"),
  capacity: document.querySelector("#capacity"),
  batteryStatus: document.querySelector("#battery-status"),
  usbOnline: document.querySelector("#usb-online"),
  usbType: document.querySelector("#usb-type"),
  bypass: document.querySelector("#bypass-enabled"),
  voltage: document.querySelector("#voltage"),
  current: document.querySelector("#current"),
  temperature: document.querySelector("#temperature"),
  updated: document.querySelector("#last-update"),
  form: document.querySelector("#config-form"),
  error: document.querySelector("#form-error"),
  save: document.querySelector("#save-button"),
  upper: document.querySelector("#upper-limit"),
  lower: document.querySelector("#lower-limit"),
  upperOutput: document.querySelector("#upper-output"),
  lowerOutput: document.querySelector("#lower-output"),
};

let formDirty = false;

function parseStatus(text) {
  return Object.fromEntries(
    text
      .trim()
      .split("\n")
      .map((line) => {
        const separator = line.indexOf("=");
        return separator < 0
          ? [line, ""]
          : [line.slice(0, separator), line.slice(separator + 1)];
      }),
  );
}

function formatMetric(value, divisor, unit) {
  const numeric = Number(value);
  if (!Number.isFinite(numeric)) return "不可用";
  return `${(numeric / divisor).toFixed(divisor === 1 ? 0 : 2)} ${unit}`;
}

function stateLabel(state) {
  return {
    UNPLUGGED: "未连接电源",
    BYPASS: "旁路供电中",
    CHARGING: "允许正常充电",
    UNAVAILABLE: "节点不可用",
  }[state] || "状态未知";
}

function onlineLabel(value) {
  if (value === "1") return "已连接";
  if (value === "0") return "未连接";
  return "不可用";
}

function updateFormOutputs() {
  elements.upperOutput.value = elements.upper.value;
  elements.lowerOutput.value = elements.lower.value;
}

function validateForm() {
  const upper = Number(elements.upper.value);
  const lower = Number(elements.lower.value);
  const valid = Number.isInteger(upper) && Number.isInteger(lower) && upper > lower;
  elements.error.textContent = valid ? "" : "充电上限必须大于恢复下限";
  elements.save.disabled = !valid;
  return valid;
}

function render(status) {
  elements.state.textContent = stateLabel(status.CONTROLLER_STATE);
  elements.capacity.textContent = status.CAPACITY === "N/A" ? "--" : status.CAPACITY;
  elements.batteryStatus.textContent = `系统状态：${status.BATTERY_STATUS}`;
  elements.usbOnline.textContent = onlineLabel(status.USB_ONLINE);
  elements.usbType.textContent = status.USB_TYPE === "N/A" ? "类型不可用" : status.USB_TYPE;
  elements.bypass.textContent =
    status.BYPASS_ENABLED === "0"
      ? "0 · 已切断充电"
      : status.BYPASS_ENABLED === "1"
        ? "1 · 允许充电"
        : "不可用";
  elements.voltage.textContent = formatMetric(status.VOLTAGE_NOW, 1_000_000, "V");
  elements.current.textContent = formatMetric(status.CURRENT_NOW, 1_000_000, "A");
  elements.temperature.textContent = formatMetric(status.TEMPERATURE, 10, "°C");
  elements.updated.textContent = `最后更新：${new Date().toLocaleTimeString("zh-CN")}`;

  if (!formDirty) {
    elements.upper.value = status.UPPER_LIMIT;
    elements.lower.value = status.LOWER_LIMIT;
    updateFormOutputs();
    validateForm();
  }
}

async function refreshStatus(showError = false) {
  try {
    const result = await exec(STATUS_COMMAND);
    if (result.errno !== 0) {
      throw new Error(result.stderr || `读取失败 (${result.errno})`);
    }
    render(parseStatus(result.stdout));
  } catch (error) {
    elements.updated.textContent = "无法读取状态，请确认正在 KernelSU 管理器中打开";
    if (showError) toast(error.message);
  }
}

elements.upper.addEventListener("input", () => {
  formDirty = true;
  updateFormOutputs();
  validateForm();
});

elements.lower.addEventListener("input", () => {
  formDirty = true;
  updateFormOutputs();
  validateForm();
});

elements.form.addEventListener("submit", async (event) => {
  event.preventDefault();
  if (!validateForm()) return;

  elements.save.disabled = true;
  elements.save.textContent = "正在保存...";

  try {
    const upper = Number(elements.upper.value);
    const lower = Number(elements.lower.value);
    const result = await exec(`${SET_CONFIG_COMMAND} ${upper} ${lower}`);
    if (result.errno !== 0) {
      throw new Error(result.stderr || `保存失败 (${result.errno})`);
    }
    formDirty = false;
    toast(result.stdout.trim() || "配置已保存");
    await refreshStatus(true);
  } catch (error) {
    elements.error.textContent = error.message;
    toast(error.message);
  } finally {
    elements.save.textContent = "保存配置";
    validateForm();
  }
});

refreshStatus(true);
window.setInterval(() => refreshStatus(false), 5000);
