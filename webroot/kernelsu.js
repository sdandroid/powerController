// Minimal offline wrapper for the official KernelSU WebUI exec bridge.
let callbackCounter = 0;

export function exec(command, options = {}) {
  return new Promise((resolve, reject) => {
    const callbackName = `exec_callback_${Date.now()}_${callbackCounter++}`;

    window[callbackName] = (errno, stdout, stderr) => {
      delete window[callbackName];
      resolve({ errno, stdout, stderr });
    };

    try {
      window.ksu.exec(command, JSON.stringify(options), callbackName);
    } catch (error) {
      delete window[callbackName];
      reject(error);
    }
  });
}

export function toast(message) {
  if (window.ksu && typeof window.ksu.toast === "function") {
    window.ksu.toast(message);
  }
}
