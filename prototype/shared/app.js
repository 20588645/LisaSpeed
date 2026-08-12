/**
 * LisaSpeed prototype shell — shared navigation / modals / connection / appearance.
 */
(function () {
  const themeFamily = document.documentElement.getAttribute("data-theme") || "tech";
  const appearanceKey = `lisaspeed-proto-appearance-${themeFamily}`;

  const state = {
    page: "home",
    connection: "disconnected",
    mode: "vpn",
    delay: 276,
    appearance: "system",
  };

  const MODE_HINTS = {
    proxy: "仅本机代理端口生效 · 不修改系统设置",
    system: "接管系统代理 · 浏览器与常规应用生效",
    vpn: "TUN 全局接管 · 所有应用与终端生效",
  };

  // Demo traffic feed: fake but live numbers so the connected state feels real.
  const demo = { timer: null, elapsed: 0, total: 0, up: 0, down: 0 };

  const $ = (sel, root = document) => root.querySelector(sel);
  const $$ = (sel, root = document) => Array.from(root.querySelectorAll(sel));

  function fmtBytes(n) {
    if (n >= 1024 ** 3) return (n / 1024 ** 3).toFixed(1) + " GB";
    if (n >= 1024 ** 2) return (n / 1024 ** 2).toFixed(1) + " MB";
    if (n >= 1024) return Math.round(n / 1024) + " KB";
    return Math.round(n) + " B";
  }

  const fmtRate = (n) => fmtBytes(n) + "/s";

  function fmtClock(sec) {
    const h = Math.floor(sec / 3600);
    const m = Math.floor((sec % 3600) / 60);
    const s = Math.floor(sec % 60);
    const mm = String(m).padStart(2, "0");
    const ss = String(s).padStart(2, "0");
    return h > 0 ? `${h}:${mm}:${ss}` : `${mm}:${ss}`;
  }

  function renderTraffic() {
    const connected = state.connection === "connected";
    const up = connected ? demo.up : 0;
    const down = connected ? demo.down : 0;
    $$("[data-traffic-up]").forEach((el) => {
      el.textContent = `↑ ${fmtRate(up)}`;
    });
    $$("[data-traffic-down]").forEach((el) => {
      el.textContent = `↓ ${fmtRate(down)}`;
    });
    $$("[data-traffic-up-val]").forEach((el) => {
      el.textContent = fmtRate(up);
    });
    $$("[data-traffic-down-val]").forEach((el) => {
      el.textContent = fmtRate(down);
    });
    $$("[data-traffic-live]").forEach((el) => {
      el.textContent = fmtRate(up + down);
    });
    $$("[data-traffic-total]").forEach((el) => {
      el.textContent = connected ? fmtBytes(demo.total) : "0 B";
    });
    $$("[data-conn-timer]").forEach((el) => {
      el.textContent = fmtClock(demo.elapsed);
    });
  }

  function demoTick() {
    demo.elapsed += 1;
    demo.up = (78 + Math.random() * 60) * 1024;
    demo.down = (22 + Math.random() * 42) * 1024;
    demo.total += demo.up + demo.down;
    renderTraffic();
  }

  function startDemo(seedSeconds = 0) {
    stopDemo();
    demo.elapsed = seedSeconds;
    demo.total = 2.4 * 1024 ** 3;
    demo.up = 96 * 1024;
    demo.down = 32 * 1024;
    renderTraffic();
    demo.timer = setInterval(demoTick, 1000);
  }

  function stopDemo() {
    if (demo.timer) {
      clearInterval(demo.timer);
      demo.timer = null;
    }
  }

  function systemScheme() {
    return window.matchMedia("(prefers-color-scheme: dark)").matches ? "dark" : "light";
  }

  function resolveScheme(appearance) {
    return appearance === "system" ? systemScheme() : appearance;
  }

  function schemeLabel(scheme) {
    return scheme === "light" ? "亮色" : "暗色";
  }

  function appearanceLabel(appearance) {
    if (appearance === "light") return "亮色";
    if (appearance === "dark") return "暗色";
    return "跟随系统";
  }

  function applyAppearance(appearance, { persist = true, toastMsg } = {}) {
    if (!["light", "dark", "system"].includes(appearance)) appearance = "system";
    state.appearance = appearance;
    const scheme = resolveScheme(appearance);
    const root = document.documentElement;
    root.setAttribute("data-appearance", appearance);
    root.setAttribute("data-color-scheme", scheme);
    $$("button[data-appearance]").forEach((el) => {
      el.classList.toggle("is-active", el.getAttribute("data-appearance") === appearance);
    });
    $$("[data-scheme-label]").forEach((el) => {
      el.textContent =
        appearance === "system"
          ? `跟随系统（${schemeLabel(scheme)}）`
          : schemeLabel(scheme);
    });
    if (persist) {
      try {
        localStorage.setItem(appearanceKey, appearance);
      } catch (_) {}
    }
    if (toastMsg) toast(toastMsg);
  }

  function loadAppearance() {
    let appearance = "system";
    try {
      const saved = localStorage.getItem(appearanceKey);
      if (saved === "light" || saved === "dark" || saved === "system") appearance = saved;
    } catch (_) {}
    applyAppearance(appearance, { persist: false });
  }

  function showPage(id) {
    state.page = id;
    $$("[data-page]").forEach((el) => {
      el.hidden = el.getAttribute("data-page") !== id;
    });
    $$("[data-nav]").forEach((el) => {
      el.classList.toggle("is-active", el.getAttribute("data-nav") === id);
    });
    const parentNav = {
      "home-a": "home",
      "home-c": "home",
      "home-d": "home",
      "subscription-detail": "subscriptions",
      "settings-general": "settings",
      "settings-connection": "settings",
      "settings-routing": "settings",
      "settings-rule": "settings",
      "settings-advanced": "settings",
      logs: "settings",
      about: "settings",
    };
    if (parentNav[id]) {
      $$("[data-nav]").forEach((el) => {
        if (el.getAttribute("data-nav") === parentNav[id]) el.classList.add("is-active");
      });
    }
    const main = $(".main");
    if (main) main.scrollTop = 0;
  }

  function openModal(id) {
    const m = $(`[data-modal="${id}"]`);
    if (!m) return;
    m.hidden = false;
    document.body.classList.add("modal-open");
  }

  function closeModal(id) {
    if (id) {
      const m = $(`[data-modal="${id}"]`);
      if (m) m.hidden = true;
    } else {
      $$("[data-modal]").forEach((m) => {
        m.hidden = true;
      });
    }
    if (!$$("[data-modal]").some((m) => !m.hidden)) {
      document.body.classList.remove("modal-open");
    }
  }

  function toast(msg) {
    const el = $("#toast");
    if (!el) return;
    el.textContent = msg;
    el.hidden = false;
    clearTimeout(el._timer);
    el._timer = setTimeout(() => {
      el.hidden = true;
    }, 1600);
  }

  function setConnection(next, { seedSeconds = 0 } = {}) {
    state.connection = next;
    document.documentElement.setAttribute("data-conn", next);
    const connected = next === "connected";
    $$("[data-conn-label]").forEach((el) => {
      el.textContent = connected ? "已连接" : next === "connecting" ? "连接中…" : "点击连接";
    });
    $$("[data-conn-sub]").forEach((el) => {
      el.textContent = connected
        ? "隧道已建立 · 流量已加密"
        : next === "connecting"
          ? "正在建立加密隧道…"
          : "流量未加密 · 点击开始加速";
    });
    $$("[data-conn-meta]").forEach((el) => {
      el.hidden = !connected;
    });
    $$("[data-delay]").forEach((el) => {
      el.hidden = !connected;
      const v = el.querySelector("[data-delay-value]");
      if (v && connected) v.textContent = String(state.delay);
    });
    $$("[data-exit-label]").forEach((el) => {
      el.textContent = connected ? "US · NTT America" : "—";
    });
    $$("[data-conn-exit]").forEach((el) => {
      el.textContent = "US · NTT America";
    });
    $$("[data-exit-ip]").forEach((el) => {
      el.textContent = connected ? "192.220.58.72" : "—";
    });
    if (connected) {
      startDemo(seedSeconds);
    } else {
      stopDemo();
      demo.elapsed = 0;
      renderTraffic();
    }
  }

  function cycleConnection() {
    if (state.connection === "disconnected") {
      setConnection("connecting");
      setTimeout(() => setConnection("connected"), 900);
    } else if (state.connection !== "connecting") {
      setConnection("disconnected");
    }
  }

  function setMode(mode) {
    state.mode = mode;
    $$("[data-mode]").forEach((el) => {
      el.classList.toggle("is-active", el.getAttribute("data-mode") === mode);
    });
    $$("[data-mode-label]").forEach((el) => {
      el.textContent = mode === "proxy" ? "代理" : mode === "system" ? "系统代理" : "VPN";
    });
    $$("[data-mode-hint]").forEach((el) => {
      el.textContent = MODE_HINTS[mode] || "";
    });
  }

  function bind() {
    document.addEventListener("click", (e) => {
      const t = e.target.closest(
        "[data-nav],[data-goto],[data-open-modal],[data-close-modal],[data-connect],[data-mode],[data-appearance],[data-action]"
      );
      if (!t) return;
      e.preventDefault();

      if (t.hasAttribute("data-action") && t.getAttribute("data-action") === "toast") {
        toast(t.getAttribute("data-toast") || "已执行（原型示意）");
      }
      if (t.hasAttribute("data-connect")) {
        cycleConnection();
        return;
      }
      if (t.hasAttribute("data-mode")) {
        setMode(t.getAttribute("data-mode"));
        return;
      }
      if (t.hasAttribute("data-appearance")) {
        const next = t.getAttribute("data-appearance");
        applyAppearance(next, {
          toastMsg: `主题已切换为${appearanceLabel(next)}`,
        });
        return;
      }
      if (t.hasAttribute("data-open-modal")) {
        openModal(t.getAttribute("data-open-modal"));
        return;
      }
      if (t.hasAttribute("data-close-modal")) {
        const id = t.getAttribute("data-close-modal");
        closeModal(id || null);
      }
      if (t.hasAttribute("data-nav") || t.hasAttribute("data-goto")) {
        showPage(t.getAttribute("data-nav") || t.getAttribute("data-goto"));
        closeModal();
      }
    });

    $$("[data-modal]").forEach((m) => {
      m.addEventListener("click", (e) => {
        if (e.target === m) closeModal(m.getAttribute("data-modal"));
      });
    });

    document.addEventListener("keydown", (e) => {
      if (e.key === "Escape") closeModal();
    });

    const mq = window.matchMedia("(prefers-color-scheme: dark)");
    const onSystemChange = () => {
      if (state.appearance === "system") applyAppearance("system", { persist: false });
    };
    if (typeof mq.addEventListener === "function") mq.addEventListener("change", onSystemChange);
    else if (typeof mq.addListener === "function") mq.addListener(onSystemChange);
  }

  document.addEventListener("DOMContentLoaded", () => {
    bind();
    loadAppearance();
    // URL params allow deep-linking a state for review/screenshots,
    // e.g. ?conn=connected&mode=proxy&appearance=light&page=nodes
    const params = new URLSearchParams(location.search);
    const appearance = params.get("appearance");
    if (appearance === "light" || appearance === "dark" || appearance === "system") {
      applyAppearance(appearance, { persist: false });
    }
    const page = params.get("page");
    showPage(page && $(`[data-page="${page}"]`) ? page : "home");
    const mode = params.get("mode");
    setMode(["proxy", "system", "vpn"].includes(mode) ? mode : "vpn");
    if (params.get("conn") === "connected") {
      setConnection("connected", { seedSeconds: 754 });
    } else {
      setConnection("disconnected");
    }
  });
})();
