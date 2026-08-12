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

  const $ = (sel, root = document) => root.querySelector(sel);
  const $$ = (sel, root = document) => Array.from(root.querySelectorAll(sel));

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

  function setConnection(next) {
    state.connection = next;
    document.documentElement.setAttribute("data-conn", next);
    $$("[data-conn-label]").forEach((el) => {
      el.textContent =
        next === "connected" ? "已连接" : next === "connecting" ? "连接中…" : "点击连接";
    });
    $$("[data-delay]").forEach((el) => {
      el.hidden = next !== "connected";
      const v = el.querySelector("[data-delay-value]");
      if (v && next === "connected") v.textContent = String(state.delay);
    });
    const connected = next === "connected";
    // Demo rates mirror the shipping app: home live = up+down; sidebar splits them.
    const up = connected ? "96 KB/s" : "0 B/s";
    const down = connected ? "32 KB/s" : "0 B/s";
    const live = connected ? "128 KB/s" : "0 B/s";
    const total = connected ? "2.4 GB" : "0 B";
    $$("[data-traffic-up]").forEach((el) => {
      el.textContent = connected ? `↑ ${up}` : "↑ 0 B/s";
    });
    $$("[data-traffic-down]").forEach((el) => {
      el.textContent = connected ? `↓ ${down}` : "↓ 0 B/s";
    });
    $$("[data-traffic-live]").forEach((el) => {
      el.textContent = live;
    });
    $$("[data-traffic-total]").forEach((el) => {
      el.textContent = total;
    });
    $$("[data-exit-label]").forEach((el) => {
      el.textContent = connected ? "US · NTT Americ…" : "—";
    });
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
    showPage("home");
    setConnection("disconnected");
    setMode("vpn");
  });
})();
