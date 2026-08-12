#!/usr/bin/env python3
"""Generate LisaSpeed tech + instrument clickable HTML prototypes."""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]  # LisaSpeed/
PROTO = ROOT / "prototype"

PAGES_NAV = [
    ("home", "主页", "home"),
    ("nodes", "节点", "nodes"),
    ("subscriptions", "订阅", "subscriptions"),
    ("settings", "设置", "settings"),
]

def shell_nav(theme: str) -> str:
    items = []
    for pid, label, ico in PAGES_NAV:
        items.append(
            f'<button type="button" class="nav-item" data-nav="{pid}">'
            f'<span class="nav-ico" data-ico="{ico}" aria-hidden="true"></span>'
            f'<span class="nav-label">{label}</span></button>'
        )
    return "\n".join(items)

HOME_HEADER = """  <header class="page-head home-head">
    <div>
      <div class="brand-line"><strong>LisaSpeed</strong> <span class="chip">0.0.1</span></div>
      <p class="muted home-sub">一键连接 · 当前订阅与模式</p>
    </div>
    <button type="button" class="btn ghost add-btn" data-open-modal="add-profile"><span class="plus">+</span> 添加订阅</button>
  </header>"""

HOME_VARIANTS = [
    ("home", "A · 居中单列"),
    ("home-b", "B · 仪表盘"),
    ("home-c", "C · 指挥条"),
    ("home-d", "D · 极简"),
]

def variant_bar(active: str) -> str:
    tabs = "".join(
        f'<button type="button" class="vtab{" is-active" if pid == active else ""}" data-goto="{pid}">{label}</button>'
        for pid, label in HOME_VARIANTS
    )
    return (
        '<div class="variant-bar"><span class="muted tiny">布局方案</span>'
        f'<div class="variant-tabs">{tabs}</div></div>'
    )

def connect_button(size: str = "") -> str:
    cls = f"connect-btn {size}".strip()
    return f"""<button type="button" class="{cls}" data-connect aria-label="连接切换">
        <span class="connect-aura" aria-hidden="true"></span>
        <span class="connect-ripple" aria-hidden="true"></span>
        <span class="connect-ring" aria-hidden="true"></span>
        <span class="connect-arc" aria-hidden="true"></span>
        <span class="connect-disc">
          <span class="connect-mark">L</span>
        </span>
      </button>"""

def page_home(theme: str = "tech") -> str:
    # Tech home v2: richer hero (status sub-line + duration/exit chips), compact
    # mode switch with a per-mode hint, up/down/total stats, current-node CTA.
    if theme == "tech":
        return f"""
<section class="page page-home" data-page="home">
{HOME_HEADER}
  {variant_bar("home")}
  <div class="home-stage">
    <button type="button" class="pill profile-pill" data-goto="subscriptions">
      <span class="pill-dot" aria-hidden="true"></span>
      <span data-profile-label>VMess</span>
      <span class="pill-chevron" aria-hidden="true">›</span>
    </button>

    <div class="connect-zone">
      <button type="button" class="connect-btn" data-connect aria-label="连接切换">
        <span class="connect-aura" aria-hidden="true"></span>
        <span class="connect-ripple" aria-hidden="true"></span>
        <span class="connect-ring" aria-hidden="true"></span>
        <span class="connect-arc" aria-hidden="true"></span>
        <span class="connect-disc">
          <span class="connect-mark">L</span>
        </span>
      </button>
      <div class="connect-copy">
        <div class="connect-status" data-conn-label>点击连接</div>
        <div class="connect-sub muted" data-conn-sub>流量未加密 · 点击开始加速</div>
        <div class="connect-meta" data-conn-meta hidden>
          <span class="conn-chip"><span class="conn-chip-k">时长</span><strong data-conn-timer>00:00</strong></span>
          <span class="conn-chip"><span class="conn-chip-k">出口</span><strong data-conn-exit>US · NTT America</strong></span>
        </div>
      </div>
    </div>

    <div class="mode-switch mode-switch-lite" role="group" aria-label="连接模式">
      <div class="seg mode-seg">
        <button type="button" data-mode="proxy">代理</button>
        <button type="button" data-mode="system">系统代理</button>
        <button type="button" data-mode="vpn">VPN</button>
      </div>
      <p class="mode-hint muted" data-mode-hint>TUN 全局接管 · 所有应用与终端生效</p>
    </div>

    <div class="home-stats">
      <div class="stat"><span class="stat-k">上行</span><span class="stat-v" data-traffic-up-val>0 B/s</span></div>
      <div class="stat"><span class="stat-k">下行</span><span class="stat-v" data-traffic-down-val>0 B/s</span></div>
      <div class="stat"><span class="stat-k">总量</span><span class="stat-v" data-traffic-total>0 B</span></div>
    </div>

    <button type="button" class="btn block node-cta" data-goto="nodes">
      <span class="node-cta-left">
        <span class="node-cta-kicker">当前节点</span>
        <strong data-node-label>美国家宽 § 0</strong>
      </span>
      <span class="node-cta-right">
        <span class="latency delay-ok"><span class="latency-dot"></span>182 ms</span>
        <span class="pill-chevron" aria-hidden="true">›</span>
      </span>
    </button>
  </div>
</section>
"""
    # Instrument keeps the legacy home layout as the alternative design.
    delay_block = (
        '<div class="delay-pill" data-delay hidden>'
        "<span>延迟</span> <strong><span data-delay-value>276</span> ms</strong>"
        "</div>"
    )
    profile_label = "VMess · 美国家宽"
    total_default = "1.2 GB"
    exit_default = "LA · NTT"
    return f"""
<section class="page page-home" data-page="home">
  <header class="page-head home-head">
    <div>
      <div class="brand-line"><strong>LisaSpeed</strong> <span class="chip">0.0.1</span></div>
      <p class="muted home-sub">一键连接 · 当前订阅与模式</p>
    </div>
    <button type="button" class="btn ghost add-btn" data-open-modal="add-profile"><span class="plus">+</span> 添加订阅</button>
  </header>
  <div class="home-stage">
    <button type="button" class="pill profile-pill" data-goto="subscriptions">
      <span class="pill-dot" aria-hidden="true"></span>
      <span data-profile-label>{profile_label}</span>
      <span class="pill-chevron" aria-hidden="true">›</span>
    </button>

    <div class="connect-zone">
      <button type="button" class="connect-btn" data-connect aria-label="连接切换">
        <span class="connect-aura" aria-hidden="true"></span>
        <span class="connect-ring" aria-hidden="true"></span>
        <span class="connect-arc" aria-hidden="true"></span>
        <span class="connect-disc">
          <span class="connect-mark">L</span>
        </span>
      </button>
      <div class="connect-copy">
        <div class="connect-status" data-conn-label>点击连接</div>
        {delay_block}
      </div>
    </div>

    <div class="mode-switch" role="group" aria-label="连接模式">
      <div class="mode-switch-top">
        <div class="mode-switch-label">连接模式</div>
        <p class="mode-hint muted">当前 <strong data-mode-label>VPN</strong></p>
      </div>
      <div class="seg mode-seg">
        <button type="button" data-mode="proxy">代理</button>
        <button type="button" data-mode="system">系统代理</button>
        <button type="button" data-mode="vpn">VPN</button>
      </div>
    </div>

    <div class="home-stats">
      <div class="stat"><span class="stat-k">实时</span><span class="stat-v" data-traffic-live>0 B/s</span></div>
      <div class="stat"><span class="stat-k">总量</span><span class="stat-v" data-traffic-total>{total_default}</span></div>
      <div class="stat"><span class="stat-k">出口</span><span class="stat-v" data-exit-label>{exit_default}</span></div>
    </div>
    <button type="button" class="btn block home-cta" data-goto="nodes">打开节点列表</button>
  </div>
</section>
"""

def page_home_b() -> str:
    """Layout B — dashboard split: hero card left, info cards right."""
    return f"""
<section class="page page-home-b" data-page="home-b">
{HOME_HEADER}
  {variant_bar("home-b")}
  <div class="home-b-grid">
    <div class="panel hb-hero">
      <button type="button" class="pill profile-pill" data-goto="subscriptions">
        <span class="pill-dot" aria-hidden="true"></span>
        <span data-profile-label>VMess</span>
        <span class="pill-chevron" aria-hidden="true">›</span>
      </button>
      {connect_button("md")}
      <div class="connect-copy hb-copy">
        <div class="connect-status" data-conn-label>点击连接</div>
        <div class="connect-sub muted" data-conn-sub>流量未加密 · 点击开始加速</div>
        <div class="connect-meta" data-conn-meta hidden>
          <span class="conn-chip"><span class="conn-chip-k">时长</span><strong data-conn-timer>00:00</strong></span>
        </div>
      </div>
      <div class="seg mode-seg hb-modes" role="group" aria-label="连接模式">
        <button type="button" data-mode="proxy">代理</button>
        <button type="button" data-mode="system">系统代理</button>
        <button type="button" data-mode="vpn">VPN</button>
      </div>
      <p class="mode-hint muted" data-mode-hint>TUN 全局接管 · 所有应用与终端生效</p>
    </div>
    <div class="hb-side">
      <div class="panel hb-card">
        <div class="hb-k">出口</div>
        <div class="hb-row"><span class="muted tiny">线路</span><span class="hb-v sm" data-exit-label>—</span></div>
        <div class="hb-row"><span class="muted tiny">检测 IP</span><span class="hb-v sm hb-ip" data-exit-ip>—</span></div>
      </div>
      <div class="panel hb-card">
        <div class="hb-k">流量</div>
        <div class="hb-row"><span class="muted tiny">上行</span><span class="hb-v sm" data-traffic-up-val>0 B/s</span></div>
        <div class="hb-row"><span class="muted tiny">下行</span><span class="hb-v sm" data-traffic-down-val>0 B/s</span></div>
        <div class="hb-row"><span class="muted tiny">总量</span><span class="hb-v sm" data-traffic-total>0 B</span></div>
      </div>
      <button type="button" class="panel hb-card hb-link" data-goto="nodes">
        <div class="hb-k">当前节点</div>
        <div class="hb-row"><strong>美国家宽 § 0</strong><span class="latency delay-ok"><span class="latency-dot"></span>182 ms</span></div>
      </button>
      <button type="button" class="panel hb-card hb-link" data-goto="subscriptions">
        <div class="hb-k">订阅</div>
        <div class="hb-row"><strong>VMess</strong><span class="muted tiny">今日已更新</span></div>
      </button>
    </div>
  </div>
</section>
"""

def page_home_c() -> str:
    """Layout C — command banner: horizontal status bar + info card row."""
    return f"""
<section class="page page-home-c" data-page="home-c">
{HOME_HEADER}
  {variant_bar("home-c")}
  <div class="panel hc-banner">
    <div class="hc-left">
      {connect_button("sm")}
      <div class="hc-copy">
        <div class="connect-status" data-conn-label>点击连接</div>
        <div class="connect-sub muted" data-conn-sub>流量未加密 · 点击开始加速</div>
        <div class="connect-meta" data-conn-meta hidden>
          <span class="conn-chip"><span class="conn-chip-k">时长</span><strong data-conn-timer>00:00</strong></span>
          <span class="conn-chip"><span class="conn-chip-k">出口</span><strong data-conn-exit>US · NTT America</strong></span>
        </div>
      </div>
    </div>
    <div class="hc-right">
      <div class="seg mode-seg hc-modes" role="group" aria-label="连接模式">
        <button type="button" data-mode="proxy">代理</button>
        <button type="button" data-mode="system">系统代理</button>
        <button type="button" data-mode="vpn">VPN</button>
      </div>
      <p class="mode-hint muted tiny" data-mode-hint>TUN 全局接管 · 所有应用与终端生效</p>
    </div>
  </div>
  <div class="hc-grid">
    <div class="panel hb-card">
      <div class="hb-k">流量</div>
      <div class="hb-row"><span class="muted tiny">上行</span><span class="hb-v sm" data-traffic-up-val>0 B/s</span></div>
      <div class="hb-row"><span class="muted tiny">下行</span><span class="hb-v sm" data-traffic-down-val>0 B/s</span></div>
      <div class="hb-row"><span class="muted tiny">总量</span><span class="hb-v sm" data-traffic-total>0 B</span></div>
    </div>
    <button type="button" class="panel hb-card hb-link" data-goto="nodes">
      <div class="hb-k">当前节点</div>
      <div class="hb-row"><strong>美国家宽 § 0</strong><span class="latency delay-ok"><span class="latency-dot"></span>182 ms</span></div>
      <div class="muted tiny">点击切换线路</div>
    </button>
    <button type="button" class="panel hb-card hb-link" data-goto="subscriptions">
      <div class="hb-k">订阅</div>
      <div class="hb-row"><strong>VMess</strong><span class="muted tiny">今日已更新</span></div>
      <div class="muted tiny">剩余流量充足</div>
    </button>
  </div>
</section>
"""

def page_home_d() -> str:
    """Layout D — zen focus: oversized button, inline stats, text-pill modes."""
    return f"""
<section class="page page-home-d" data-page="home-d">
{HOME_HEADER}
  {variant_bar("home-d")}
  <div class="home-d-stage">
    <button type="button" class="pill profile-pill" data-goto="subscriptions">
      <span class="pill-dot" aria-hidden="true"></span>
      <span data-profile-label>VMess</span>
      <span class="pill-chevron" aria-hidden="true">›</span>
    </button>
    {connect_button("xl")}
    <div class="connect-copy hd-copy">
      <div class="connect-status" data-conn-label>点击连接</div>
      <div class="connect-sub muted" data-conn-sub>流量未加密 · 点击开始加速</div>
      <div class="connect-meta" data-conn-meta hidden>
        <span class="conn-chip"><span class="conn-chip-k">时长</span><strong data-conn-timer>00:00</strong></span>
        <span class="conn-chip"><span class="conn-chip-k">出口</span><strong data-conn-exit>US · NTT America</strong></span>
      </div>
    </div>
    <div class="hd-stats">
      <span data-traffic-up>↑ 0 B/s</span>
      <span data-traffic-down>↓ 0 B/s</span>
      <span>共 <span data-traffic-total>0 B</span></span>
    </div>
    <div class="hd-modes" role="group" aria-label="连接模式">
      <button type="button" data-mode="proxy">代理</button>
      <button type="button" data-mode="system">系统代理</button>
      <button type="button" data-mode="vpn">VPN</button>
    </div>
    <button type="button" class="hd-node" data-goto="nodes">节点 · 美国家宽 § 0 · 182 ms ›</button>
  </div>
</section>
"""

def page_proxies() -> str:
    rows = ""
    nodes = [
        ("美国家宽 § 0", "美国 · 家庭", "182", "ok", True),
        ("美国宽带 § 1", "美国 · 机房", "241", "warn", False),
        ("日本优化 § 2", "日本 · 优化", "98", "ok", False),
        ("新加坡 § 3", "新加坡", "126", "ok", False),
        ("香港 § 4", "香港", "64", "good", False),
    ]
    for name, meta, delay, tone, active in nodes:
        badge = '<span class="node-badge">当前</span>' if active else ""
        rows += (
            f'<button type="button" class="list-row node-row {"is-active" if active else ""}" '
            f'data-action="toast" data-toast="已选择：{name}">'
            f'<div class="list-main"><div class="row gap">{badge}<strong>{name}</strong></div>'
            f'<div class="muted">{meta} · vmess</div></div>'
            f'<span class="latency delay-{tone}"><span class="latency-dot"></span>{delay} ms</span></button>'
        )
    return f"""
<section class="page" data-page="nodes">
  <header class="page-head">
    <div>
      <p class="eyebrow">Nodes</p>
      <h1>节点</h1>
      <p class="muted">选择线路并测速</p>
    </div>
    <div class="row gap">
      <button type="button" class="btn ghost" data-action="toast" data-toast="排序已切换">排序</button>
      <button type="button" class="btn primary" data-action="toast" data-toast="正在测速…">测速</button>
    </div>
  </header>
  <div class="toolbar-note muted">共 5 个节点 · 点击切换</div>
  <div class="list">{rows}</div>
</section>
"""

def page_profiles() -> str:
    return """
<section class="page" data-page="subscriptions">
  <header class="page-head">
    <div>
      <p class="eyebrow">Subscriptions</p>
      <h1>订阅</h1>
      <p class="muted">管理订阅与本地配置</p>
    </div>
    <button type="button" class="btn primary" data-open-modal="add-profile">添加</button>
  </header>
  <div class="list profile-list">
    <div class="list-row profile-row is-active">
      <div class="profile-main">
        <div class="row gap wrap">
          <strong>VMess · 美国家宽</strong>
          <span class="tag tag-active">使用中</span>
          <span class="tag">订阅</span>
        </div>
        <div class="muted">今日已更新 · 剩余流量充足</div>
      </div>
      <div class="row gap actions">
        <button type="button" class="btn tiny" data-action="toast" data-toast="正在更新订阅">更新</button>
        <button type="button" class="btn tiny" data-goto="subscription-detail">编辑</button>
        <button type="button" class="btn tiny danger" data-open-modal="confirm">删除</button>
      </div>
    </div>
    <div class="list-row profile-row">
      <div class="profile-main">
        <div class="row gap wrap">
          <strong>备用订阅</strong>
          <span class="tag">本地</span>
        </div>
        <div class="muted">未激活 · 可随时切换</div>
      </div>
      <div class="row gap actions">
        <button type="button" class="btn tiny" data-action="toast" data-toast="已设为当前配置">激活</button>
        <button type="button" class="btn tiny" data-goto="subscription-detail">编辑</button>
      </div>
    </div>
  </div>
</section>
"""

def page_profile_detail() -> str:
    return """
<section class="page" data-page="subscription-detail">
  <header class="page-head">
    <div class="row gap head-nav">
      <button type="button" class="btn icon-btn" data-goto="subscriptions" aria-label="返回">←</button>
      <div>
        <p class="eyebrow">Edit</p>
        <h1>订阅详情</h1>
        <p class="muted">编辑名称与更新策略</p>
      </div>
    </div>
    <button type="button" class="btn primary" data-action="toast" data-toast="已保存" data-goto="subscriptions">保存</button>
  </header>
  <div class="form panel form-card">
    <div class="form-section-title">基本信息</div>
    <label>名称<input value="VMess · 美国家宽"></label>
    <label>订阅 URL<input value="https://example.com/sub" readonly></label>
    <div class="form-section-title">更新策略</div>
    <label class="check switch"><input type="checkbox" checked><span>自动更新</span></label>
    <label>更新间隔（小时）<input type="number" value="12"></label>
  </div>
</section>
"""

def page_settings() -> str:
    cards = [
        ("settings-general", "通用", "语言、主题、开机自启", "01"),
        ("settings-connection", "连接", "模式偏好、端口、VPN 共享", "02"),
        ("settings-routing", "分流", "规则列表与地区策略", "03"),
        ("settings-advanced", "高级", "DNS、TLS、链路增强", "04"),
        ("logs", "诊断", "运行日志与排查", "05"),
        ("about", "关于", "版本、更新、工作目录", "06"),
    ]
    grid = "".join(
        f'<button type="button" class="setting-card" data-goto="{gid}">'
        f'<span class="setting-idx">{idx}</span>'
        f'<span class="setting-body"><strong>{title}</strong><span class="muted">{desc}</span></span>'
        f'<span class="setting-chevron" aria-hidden="true">›</span></button>'
        for gid, title, desc, idx in cards
    )
    return f"""
<section class="page" data-page="settings">
  <header class="page-head">
    <div>
      <p class="eyebrow">Settings</p>
      <h1>设置</h1>
      <p class="muted">常用项靠前 · 高级项收纳</p>
    </div>
    <div class="row gap">
      <button type="button" class="btn ghost" data-action="toast" data-toast="已导入选项">导入</button>
      <button type="button" class="btn ghost" data-action="toast" data-toast="已导出选项">导出</button>
      <button type="button" class="btn ghost" data-action="toast" data-toast="已重置">重置</button>
    </div>
  </header>
  <div class="settings-grid">{grid}</div>
</section>
"""

def settings_sub(page_id: str, title: str, body: str, back: str = "settings", eyebrow: str = "Settings") -> str:
    return f"""
<section class="page" data-page="{page_id}">
  <header class="page-head">
    <div class="row gap head-nav">
      <button type="button" class="btn icon-btn" data-goto="{back}" aria-label="返回">←</button>
      <div>
        <p class="eyebrow">{eyebrow}</p>
        <h1>{title}</h1>
      </div>
    </div>
  </header>
  <div class="form panel form-card">{body}</div>
</section>
"""

def page_routing() -> str:
    return """
<section class="page" data-page="settings-routing">
  <header class="page-head">
    <div class="row gap head-nav">
      <button type="button" class="btn icon-btn" data-goto="settings" aria-label="返回">←</button>
      <div>
        <p class="eyebrow">Routing</p>
        <h1>分流</h1>
        <p class="muted">规则与地区策略</p>
      </div>
    </div>
    <div class="row gap">
      <button type="button" class="btn ghost" data-action="toast" data-toast="已添加预设：拦截广告">预设</button>
      <button type="button" class="btn primary" data-goto="settings-rule">新建规则</button>
    </div>
  </header>
  <div class="section-block">
    <div class="section-label">规则列表</div>
    <div class="list">
      <button type="button" class="list-row" data-goto="settings-rule">
        <div class="list-main"><strong>国内直连</strong><div class="muted">geoip-cn / geosite-cn → direct</div></div>
        <span class="row-meta">编辑 ›</span>
      </button>
      <button type="button" class="list-row" data-goto="settings-rule">
        <div class="list-main"><strong>广告拦截</strong><div class="muted">ads → block</div></div>
        <span class="row-meta">编辑 ›</span>
      </button>
    </div>
  </div>
  <div class="panel form form-card section-block">
    <div class="form-section-title">分流通用选项</div>
    <label>地区<select><option>中国</option><option>其他</option></select></label>
    <label>IPv6<select><option>禁用</option><option>启用</option></select></label>
  </div>
</section>
"""

def page_logs() -> str:
    entries = [
        ("10:30:12", "info", "PROBE", "探测线路质量"),
        ("10:31:12", "ok", "CONNECTED", "隧道已建立"),
        ("10:32:12", "info", "PROBE", "探测线路质量"),
        ("10:33:12", "ok", "CONNECTED", "隧道已建立"),
        ("10:34:12", "warn", "RETRY", "短暂抖动，自动重试"),
        ("10:35:12", "ok", "CONNECTED", "隧道已建立"),
        ("10:36:12", "info", "PROBE", "探测线路质量"),
        ("10:37:12", "ok", "CONNECTED", "隧道已建立"),
    ]
    lines = "\n".join(
        f'<div class="log-line">'
        f'<span class="mono muted log-time">{t}</span>'
        f'<span class="log-level log-{level}">{code}</span>'
        f'<span class="log-msg">{msg}</span></div>'
        for t, level, code, msg in entries
    )
    return f"""
<section class="page" data-page="logs">
  <header class="page-head">
    <div class="row gap head-nav">
      <button type="button" class="btn icon-btn" data-goto="settings" aria-label="返回">←</button>
      <div>
        <p class="eyebrow">Diagnostics</p>
        <h1>诊断</h1>
        <p class="muted">核心与应用日志</p>
      </div>
    </div>
    <div class="row gap">
      <button type="button" class="btn ghost" data-action="toast" data-toast="已暂停">暂停</button>
      <button type="button" class="btn ghost" data-action="toast" data-toast="已清除">清除</button>
      <button type="button" class="btn ghost" data-action="toast" data-toast="已分享日志">分享</button>
    </div>
  </header>
  <div class="log-shell panel">
    <div class="log-toolbar">
      <span class="muted tiny">core · app</span>
      <span class="mono tiny muted">live</span>
    </div>
    <div class="log-panel">{lines}</div>
  </div>
</section>
"""

def page_about() -> str:
    return """
<section class="page" data-page="about">
  <header class="page-head">
    <div class="row gap head-nav">
      <button type="button" class="btn icon-btn" data-goto="settings" aria-label="返回">←</button>
      <div>
        <p class="eyebrow">About</p>
        <h1>关于</h1>
        <p class="muted">LisaSpeed 0.0.1</p>
      </div>
    </div>
    <button type="button" class="btn primary" data-action="toast" data-toast="已是最新版本">检查更新</button>
  </header>
  <div class="panel about-card">
    <div class="about-logo"><span class="logo-mark xl">L</span></div>
    <h2>LisaSpeed</h2>
    <p class="muted about-lead">macOS 本地加速客户端 · 原型演示</p>
    <div class="about-meta">
      <div><span class="muted">版本</span><strong>0.0.1</strong></div>
      <div><span class="muted">渠道</span><strong>dev</strong></div>
      <div><span class="muted">平台</span><strong>macOS</strong></div>
    </div>
    <div class="row gap wrap about-actions">
      <button type="button" class="btn ghost" data-action="toast" data-toast="已打开工作目录">工作目录</button>
      <button type="button" class="btn ghost" data-action="toast" data-toast="打开 GitHub">源码</button>
      <button type="button" class="btn ghost" data-action="toast" data-toast="已复制版本信息">复制信息</button>
    </div>
  </div>
</section>
"""

def modals() -> str:
    return """
<div class="modal" data-modal="add-profile" hidden>
  <div class="modal-card">
    <header class="modal-head"><h2>添加订阅</h2><button type="button" class="btn ghost" data-close-modal="add-profile">关闭</button></header>
    <div class="modal-body stack">
      <button type="button" class="btn block modal-choice" data-action="toast" data-toast="已从剪贴板导入" data-close-modal="add-profile">
        <strong>从剪贴板添加</strong><span class="muted">读取订阅链接或分享内容</span>
      </button>
      <button type="button" class="btn block modal-choice" data-action="toast" data-toast="已选择文件" data-close-modal="add-profile">
        <strong>从文件导入</strong><span class="muted">支持常见订阅与配置文件</span>
      </button>
      <div class="form form-card nested">
        <div class="form-section-title">手动添加</div>
        <label>名称<input placeholder="我的订阅"></label>
        <label>URL<input placeholder="https://"></label>
        <button type="button" class="btn primary block" data-action="toast" data-toast="已添加订阅" data-close-modal="add-profile">确认添加</button>
      </div>
    </div>
  </div>
</div>
<div class="modal" data-modal="confirm" hidden>
  <div class="modal-card narrow">
    <header class="modal-head"><h2>确认删除</h2></header>
    <div class="modal-body">
      <p class="confirm-copy">删除后无法恢复，确定继续？</p>
      <div class="row gap modal-actions">
        <button type="button" class="btn ghost" data-close-modal="confirm">取消</button>
        <button type="button" class="btn danger solid" data-action="toast" data-toast="已删除" data-close-modal="confirm">删除</button>
      </div>
    </div>
  </div>
</div>
"""

def all_pages(theme: str = "tech") -> str:
    home_variants = (
        [page_home_b(), page_home_c(), page_home_d()] if theme == "tech" else []
    )
    return "\n".join([
        page_home(theme),
        *home_variants,
        page_proxies(),
        page_profiles(),
        page_profile_detail(),
        page_settings(),
        settings_sub("settings-general", "通用", """
          <div class="form-section-title">语言与外观</div>
          <label>语言<select><option>简体中文</option><option>English</option></select></label>
          <div class="appearance-block">
            <div class="appearance-label">主题模式</div>
            <div class="seg appearance-seg" role="group" aria-label="主题模式">
              <button type="button" data-appearance="light">亮色</button>
              <button type="button" data-appearance="dark">暗色</button>
              <button type="button" data-appearance="system" class="is-active">跟随系统</button>
            </div>
            <p class="muted tiny appearance-hint">当前生效：<strong data-scheme-label>暗色</strong></p>
          </div>
          <div class="form-section-title">启动与关闭</div>
          <label>关闭窗口时<select><option>询问</option><option>最小化到托盘</option><option>退出</option></select></label>
          <label class="check switch"><input type="checkbox" checked><span>开机自启</span></label>
          <label class="check switch"><input type="checkbox"><span>静默启动</span></label>
        """, eyebrow="General"),
        settings_sub("settings-connection", "连接", """
          <div class="form-section-title">默认模式</div>
          <p class="muted tiny form-hint">主页可随时切换；此处为下次启动默认值（原型示意）</p>
          <label>服务模式<select><option>VPN</option><option>系统代理</option><option>代理</option></select></label>
          <label class="check switch"><input type="checkbox" checked><span>严格路由</span></label>
          <div class="form-section-title">端口</div>
          <div class="form-grid-2">
            <label>混合端口<input value="12334"></label>
            <label>直连端口<input value="12335"></label>
          </div>
          <label class="check switch"><input type="checkbox"><span>允许局域网共享（VPN）</span></label>
        """, eyebrow="Connection"),
        page_routing(),
        settings_sub("settings-rule", "规则编辑", """
          <div class="form-section-title">规则内容</div>
          <label>名称<input value="国内直连"></label>
          <label>出站<select><option>直连</option><option>代理</option><option>拦截</option></select></label>
          <label>规则集<input value="geoip-cn, geosite-cn"></label>
          <button type="button" class="btn primary" data-action="toast" data-toast="规则已保存" data-goto="settings-routing">保存</button>
        """, back="settings-routing", eyebrow="Rule"),
        settings_sub("settings-advanced", "高级", """
          <div class="form-section-title">DNS</div>
          <label>远程 DNS<input value="tcp://8.8.8.8"></label>
          <label>直连 DNS<input value="223.5.5.5"></label>
          <label>域名策略<select><option>AsIs</option><option>PreferIPv4</option></select></label>
          <label class="check switch"><input type="checkbox" checked><span>启用伪造 DNS</span></label>
          <div class="form-section-title">TLS 技巧</div>
          <label class="check switch"><input type="checkbox"><span>启用 TLS 分片</span></label>
          <label>分片大小<input value="10-100"></label>
          <label class="check switch"><input type="checkbox"><span>混合大小写 SNI</span></label>
          <label class="check switch"><input type="checkbox"><span>启用填充</span></label>
          <div class="form-section-title">链路增强</div>
          <div class="chain">
            <div class="chain-node"><span class="chain-step">1</span><div><strong>应用</strong><div class="muted">流量入口</div></div></div>
            <div class="chain-node on"><span class="chain-step">2</span><div><strong>主订阅</strong><div class="muted">VMess · 当前</div></div></div>
            <div class="chain-node"><span class="chain-step">3</span><div><strong>分流</strong><div class="muted">规则出口</div></div></div>
          </div>
          <label class="check switch"><input type="checkbox"><span>启用 WARP</span></label>
          <label class="check switch"><input type="checkbox"><span>启用 Psiphon</span></label>
        """, eyebrow="Advanced"),
        page_logs(),
        page_about(),
    ])

def html_doc(theme: str, title: str) -> str:
    font_link = ""
    if theme == "tech":
        font_link = (
            '  <link rel="preconnect" href="https://fonts.googleapis.com" />\n'
            '  <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin />\n'
            '  <link href="https://fonts.googleapis.com/css2?family=JetBrains+Mono:wght@400;600&family=Manrope:wght@400;500;600;700;800&display=swap" rel="stylesheet" />\n'
        )
    sidebar_tag = "本地加速" if theme == "tech" else "Instrument 原型"
    if theme == "tech":
        sidebar_traffic = """          <div class="traffic-row"><span class="muted">上行</span> <strong data-traffic-up>↑ 0 B/s</strong></div>
          <div class="traffic-row"><span class="muted">下行</span> <strong data-traffic-down>↓ 0 B/s</strong></div>
          <div class="traffic-row"><span class="muted">总量</span> <strong data-traffic-total>0 B</strong></div>
          <div class="traffic-row"><span class="muted">连接模式</span> <strong data-mode-label>VPN</strong></div>"""
    else:
        sidebar_traffic = """          <div class="traffic-row"><span class="muted">实时</span> <strong data-traffic-live>0 B/s</strong></div>
          <div class="traffic-row"><span class="muted">模式</span> <strong data-mode-label>VPN</strong></div>"""
    return f"""<!DOCTYPE html>
<html lang="zh-CN" data-theme="{theme}" data-appearance="system" data-color-scheme="dark">
<head>
  <meta charset="UTF-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1" />
  <meta name="color-scheme" content="light dark" />
  <title>{title}</title>
{font_link}  <link rel="stylesheet" href="css/tokens.css" />
  <link rel="stylesheet" href="css/app.css" />
  <script>
    (function () {{
      try {{
        var key = "lisaspeed-proto-appearance-" + document.documentElement.getAttribute("data-theme");
        var saved = localStorage.getItem(key);
        if (saved === "light" || saved === "dark" || saved === "system") {{
          document.documentElement.setAttribute("data-appearance", saved);
        }}
        var appearance = document.documentElement.getAttribute("data-appearance") || "system";
        var scheme = appearance;
        if (appearance === "system") {{
          scheme = window.matchMedia("(prefers-color-scheme: dark)").matches ? "dark" : "light";
        }}
        document.documentElement.setAttribute("data-color-scheme", scheme);
      }} catch (e) {{}}
    }})();
  </script>
</head>
<body>
  <div class="desktop-frame" role="application" aria-label="LisaSpeed {theme}">
    <aside class="sidebar">
      <div class="sidebar-brand">
        <span class="logo-mark">L</span>
        <div>
          <strong>LisaSpeed</strong>
          <div class="muted tiny sidebar-tag">{sidebar_tag}</div>
        </div>
      </div>
      <nav class="nav">{shell_nav(theme)}</nav>
      <div class="sidebar-foot">
        <div class="traffic">
{sidebar_traffic}
        </div>
      </div>
    </aside>
    <main class="main">
      {all_pages(theme)}
    </main>
  </div>
  {modals()}
  <div id="toast" class="toast" hidden></div>
  <script src="../shared/app.js"></script>
</body>
</html>
"""

TECH_TOKENS = """
:root {
  --radius: 16px;
  --font: "Manrope", "PingFang SC", "Segoe UI", sans-serif;
  --mono: "JetBrains Mono", ui-monospace, Menlo, monospace;
  --ease: cubic-bezier(0.22, 1, 0.36, 1);
}

html[data-color-scheme="dark"] {
  color-scheme: dark;
  --bg: #06090f;
  --bg-elev: #0b1220;
  --bg-panel: rgba(17, 28, 44, 0.82);
  --bg-panel-solid: #111c2c;
  --line: rgba(94, 234, 212, 0.14);
  --line-strong: rgba(94, 234, 212, 0.28);
  --text: #eaf3ff;
  --muted: #8aa0b8;
  --accent: #2ee6c5;
  --accent-2: #4d93ff;
  --danger: #ff5d6c;
  --ok: #2ee6c5;
  --warn: #f0b429;
  --shadow: 0 0 0 1px rgba(46, 230, 197, 0.06), 0 24px 64px rgba(0, 0, 0, 0.5);
  --grid: rgba(46, 230, 197, 0.045);
  --glow: 0 0 48px rgba(46, 230, 197, 0.32);
  --glow-soft: 0 0 24px rgba(46, 230, 197, 0.16);
  --connect-core: radial-gradient(circle at 32% 28%, rgba(46, 230, 197, 0.28), #0d1828 58%, #0a1320);
  --connect-ring: rgba(46, 230, 197, 0.45);
  --page-shell: radial-gradient(1200px 600px at 50% -10%, #152033, #0b0e14 55%, #07090d);
  --glass: rgba(10, 18, 32, 0.55);
  --sidebar-wash: linear-gradient(180deg, rgba(46, 230, 197, 0.06), transparent 42%);
}

html[data-color-scheme="light"] {
  color-scheme: light;
  --bg: #f3f7fb;
  --bg-elev: #ffffff;
  --bg-panel: rgba(255, 255, 255, 0.86);
  --bg-panel-solid: #ffffff;
  --line: rgba(15, 40, 55, 0.1);
  --line-strong: rgba(13, 159, 136, 0.28);
  --text: #102033;
  --muted: #5d738a;
  --accent: #0c9a84;
  --accent-2: #2f6fed;
  --danger: #d93848;
  --ok: #0c9a84;
  --warn: #c98500;
  --shadow: 0 1px 0 rgba(255,255,255,.95), 0 18px 42px rgba(16, 32, 51, 0.08);
  --grid: rgba(13, 159, 136, 0.06);
  --glow: 0 0 30px rgba(12, 154, 132, 0.2);
  --glow-soft: 0 0 16px rgba(12, 154, 132, 0.12);
  --connect-core: radial-gradient(circle at 32% 28%, rgba(12, 154, 132, 0.16), #fff 62%);
  --connect-ring: rgba(12, 154, 132, 0.35);
  --page-shell: radial-gradient(1000px 520px at 50% -8%, #dfeaf3, #cfd8e2 60%, #c5ced8);
  --glass: rgba(255, 255, 255, 0.72);
  --sidebar-wash: linear-gradient(180deg, rgba(12, 154, 132, 0.08), transparent 42%);
}
"""

INSTRUMENT_TOKENS = """
:root {
  --radius: 10px;
  --font: "IBM Plex Sans", "PingFang SC", "Segoe UI", sans-serif;
  --mono: "IBM Plex Mono", ui-monospace, Menlo, monospace;
}

html[data-color-scheme="light"] {
  color-scheme: light;
  --bg: #eef1f4;
  --bg-elev: #ffffff;
  --bg-panel: #f7f8fa;
  --line: #d5dbe3;
  --text: #1a2332;
  --muted: #66768a;
  --accent: #0b5fff;
  --accent-2: #0b3d5c;
  --danger: #c62828;
  --ok: #0f8a5f;
  --shadow: 0 1px 0 rgba(255,255,255,.8), 0 10px 30px rgba(26,35,50,.08);
  --grid: rgba(11, 95, 255, 0.06);
  --glow: none;
  --connect-core: #ffffff;
  --connect-ring: #c9d6ea;
  --page-shell: #222;
}

html[data-color-scheme="dark"] {
  color-scheme: dark;
  --bg: #12161c;
  --bg-elev: #1a2028;
  --bg-panel: #1e2530;
  --line: rgba(220, 230, 245, 0.12);
  --text: #e8edf4;
  --muted: #8b97a8;
  --accent: #4d8aff;
  --accent-2: #8ab4ff;
  --danger: #ff6b6b;
  --ok: #3dd68c;
  --shadow: 0 0 0 1px rgba(77, 138, 255, 0.08), 0 16px 40px rgba(0,0,0,.45);
  --grid: rgba(77, 138, 255, 0.07);
  --glow: none;
  --connect-core: #232a35;
  --connect-ring: #3a4556;
  --page-shell: #0a0c10;
}
"""

APP_CSS = """
* { box-sizing: border-box; }
html, body { margin: 0; height: 100%; font-family: var(--font); color: var(--text); background: var(--page-shell, #222); }
button, input, select { font: inherit; }
button { cursor: pointer; }
.muted { color: var(--muted); }
.tiny { font-size: 12px; }
.mono { font-family: var(--mono); font-size: 12px; }
.row { display: flex; align-items: center; }
.gap { gap: 8px; }
.wrap { flex-wrap: wrap; }
.stack { display: grid; gap: 10px; }

.desktop-frame {
  width: min(1180px, 100vw);
  height: min(820px, 100vh);
  margin: 28px auto;
  display: grid;
  grid-template-columns: 216px 1fr;
  background: var(--bg);
  border-radius: 18px;
  overflow: hidden;
  box-shadow: var(--shadow);
  border: 1px solid var(--line);
}

.sidebar {
  display: flex; flex-direction: column;
  background: var(--bg-elev);
  border-right: 1px solid var(--line);
  padding: 18px 12px 14px;
  position: relative;
}
.sidebar-brand { display: flex; gap: 12px; align-items: center; padding: 4px 10px 18px; }
.sidebar-tag { letter-spacing: 0.04em; }
.nav { display: grid; gap: 4px; flex: 1; align-content: start; }
.nav-item {
  display: flex; gap: 12px; align-items: center;
  border: 0; background: transparent; color: var(--muted);
  padding: 11px 12px; border-radius: 12px; text-align: left;
  transition: background .18s var(--ease, ease), color .18s var(--ease, ease), transform .18s var(--ease, ease);
}
.nav-item.is-active, .nav-item:hover { background: color-mix(in srgb, var(--accent) 14%, transparent); color: var(--text); }
.nav-item:active { transform: scale(0.985); }
.nav-ico {
  width: 18px; height: 18px; border-radius: 6px;
  background: color-mix(in srgb, var(--muted) 28%, transparent);
  position: relative; flex: 0 0 auto;
}
.nav-item.is-active .nav-ico { background: color-mix(in srgb, var(--accent) 28%, transparent); box-shadow: var(--glow-soft, none); }
.nav-ico::after {
  content: "";
  position: absolute; inset: 5px;
  border-radius: 2px;
  background: var(--muted);
}
.nav-item.is-active .nav-ico::after { background: var(--accent); }
.nav-ico[data-ico="home"]::after { border-radius: 50%; inset: 5px; }
.nav-ico[data-ico="nodes"]::after { inset: 4px 5px; border-radius: 1px; clip-path: polygon(20% 0, 80% 0, 100% 100%, 0 100%); }
.nav-ico[data-ico="subscriptions"]::after { inset: 4px 6px; border-radius: 1px; }
.nav-ico[data-ico="settings"]::after { inset: 4px; border-radius: 50%; box-shadow: inset 0 0 0 2px var(--bg-elev); }
.nav-ico[data-ico="logs"]::after { inset: 5px 4px; border-radius: 1px; height: 2px; top: 8px; box-shadow: 0 4px 0 var(--muted), 0 8px 0 var(--muted); background: var(--muted); }
.nav-item.is-active .nav-ico[data-ico="logs"]::after { box-shadow: 0 4px 0 var(--accent), 0 8px 0 var(--accent); }
.nav-ico[data-ico="about"]::after { inset: 5px; border-radius: 50%; }
.sidebar-foot { border-top: 1px solid var(--line); padding-top: 12px; font-size: 12px; }
.traffic { display: grid; gap: 8px; padding: 10px 12px; border-radius: 12px; background: color-mix(in srgb, var(--accent) 6%, transparent); border: 1px solid var(--line); }
.traffic-row { display: flex; justify-content: space-between; gap: 8px; }

.main {
  position: relative;
  overflow: auto;
  background:
    radial-gradient(520px 280px at 70% -10%, color-mix(in srgb, var(--accent-2) 16%, transparent), transparent 70%),
    radial-gradient(420px 240px at 10% 0%, color-mix(in srgb, var(--accent) 12%, transparent), transparent 65%),
    linear-gradient(180deg, color-mix(in srgb, var(--accent) 5%, transparent), transparent 200px),
    repeating-linear-gradient(0deg, transparent, transparent 23px, var(--grid) 24px),
    repeating-linear-gradient(90deg, transparent, transparent 23px, var(--grid) 24px),
    var(--bg);
}
.page { padding: 22px 28px 64px; min-height: 100%; max-width: 920px; }
.page[hidden] { display: none !important; }
.page-head { display: flex; justify-content: space-between; gap: 16px; align-items: flex-start; margin-bottom: 20px; }
.page-head h1 { margin: 0; font-size: 22px; letter-spacing: -0.02em; }
.page-head .muted { margin: 6px 0 0; font-size: 13px; }
.brand-line { font-size: 20px; letter-spacing: -0.02em; }
.home-sub { margin: 6px 0 0; font-size: 13px; }
.chip { display: inline-block; padding: 2px 8px; border-radius: 999px; background: color-mix(in srgb, var(--accent) 16%, transparent); color: var(--accent); font-size: 11px; font-weight: 700; vertical-align: 2px; letter-spacing: 0.04em; }

.btn {
  border: 1px solid var(--line);
  background: var(--bg-panel-solid, var(--bg-panel));
  color: var(--text);
  border-radius: 11px;
  padding: 8px 12px;
  transition: border-color .18s ease, background .18s ease, transform .18s ease, box-shadow .18s ease;
}
.btn:hover { border-color: color-mix(in srgb, var(--accent) 50%, var(--line)); }
.btn:active { transform: translateY(1px); }
.btn.primary { background: var(--accent); color: #041016; border-color: transparent; font-weight: 700; box-shadow: var(--glow-soft, none); }
[data-theme="instrument"] .btn.primary { color: #fff; box-shadow: none; }
.btn.ghost { background: transparent; }
.btn.block { width: 100%; }
.btn.tiny { padding: 5px 9px; font-size: 12px; border-radius: 8px; }
.btn.danger { color: var(--danger); border-color: color-mix(in srgb, var(--danger) 40%, var(--line)); }
.add-btn .plus { font-weight: 700; margin-right: 2px; }

.panel {
  background: var(--bg-panel-solid, var(--bg-panel));
  border: 1px solid var(--line);
  border-radius: var(--radius);
  padding: 16px;
  box-shadow: var(--shadow);
}
.list { display: grid; gap: 8px; }
.list-row {
  width: 100%;
  display: flex; justify-content: space-between; align-items: center; gap: 12px;
  text-align: left;
  border: 1px solid var(--line);
  background: var(--bg-panel-solid, var(--bg-panel));
  color: var(--text);
  border-radius: 14px;
  padding: 13px 14px;
  transition: border-color .18s ease, transform .18s ease, background .18s ease;
}
.list-row:hover { border-color: var(--line-strong, var(--accent)); }
.list-row.is-active { border-color: var(--accent); box-shadow: inset 3px 0 0 var(--accent); background: color-mix(in srgb, var(--accent) 8%, var(--bg-panel-solid, var(--bg-panel))); }
.list-main { min-width: 0; }
.delay { font-weight: 600; }
.delay-good { color: var(--ok); }
.delay-ok { color: var(--accent-2, var(--accent)); }
.delay-warn { color: var(--warn, #f0b429); }

.form { display: grid; gap: 12px; }
.form label { display: grid; gap: 6px; font-size: 13px; color: var(--muted); }
.form input, .form select {
  border: 1px solid var(--line); background: var(--bg-elev); color: var(--text);
  border-radius: 10px; padding: 10px 12px;
  transition: border-color .18s ease, box-shadow .18s ease;
}
.form input:focus, .form select:focus {
  outline: none; border-color: color-mix(in srgb, var(--accent) 55%, var(--line));
  box-shadow: 0 0 0 3px color-mix(in srgb, var(--accent) 16%, transparent);
}
.check { display: flex !important; align-items: center; gap: 8px; grid-template-columns: none; }

.appearance-block {
  display: grid;
  gap: 10px;
  padding: 14px;
  border: 1px solid var(--line);
  border-radius: var(--radius);
  background: var(--bg-elev);
}
.appearance-label { font-size: 13px; color: var(--muted); }
.appearance-seg button { min-height: 40px; font-weight: 600; }
.appearance-hint { margin: 0; }
.appearance-hint strong { color: var(--accent); }

.settings-grid { display: grid; grid-template-columns: repeat(2, minmax(0, 1fr)); gap: 12px; }
.setting-card {
  display: grid; grid-template-columns: auto 1fr auto; gap: 12px; align-items: center;
  text-align: left;
  padding: 16px; border-radius: var(--radius);
  border: 1px solid var(--line); background: var(--bg-panel-solid, var(--bg-panel)); color: var(--text);
  transition: border-color .18s ease, transform .18s ease, box-shadow .18s ease;
}
.setting-card:hover { border-color: var(--accent); transform: translateY(-1px); box-shadow: var(--glow-soft, none); }
.setting-idx {
  width: 34px; height: 34px; border-radius: 10px;
  display: grid; place-items: center;
  font-family: var(--mono); font-size: 11px; font-weight: 600;
  color: var(--accent); background: color-mix(in srgb, var(--accent) 12%, transparent);
}
.setting-body { display: grid; gap: 4px; }
.setting-body strong { font-size: 15px; }
.setting-chevron { color: var(--muted); font-size: 20px; line-height: 1; }

.home-stage {
  display: grid; justify-items: center; gap: 16px;
  padding: 8px 0 28px; width: min(460px, 100%); margin: 0 auto;
}
.pill {
  border: 1px solid var(--line); background: var(--bg-panel-solid, var(--bg-panel)); color: var(--text);
  border-radius: 999px; padding: 8px 14px; font-size: 13px;
  display: inline-flex; align-items: center; gap: 8px;
  transition: border-color .18s ease, transform .18s ease;
}
.pill:hover { border-color: var(--line-strong, var(--accent)); }
.profile-pill { max-width: 100%; }
.pill-dot {
  width: 7px; height: 7px; border-radius: 50%;
  background: var(--accent); box-shadow: 0 0 10px color-mix(in srgb, var(--accent) 70%, transparent);
}
.pill-chevron { color: var(--muted); font-size: 16px; }
.mode-switch {
  width: 100%;
  padding: 12px;
  border-radius: var(--radius);
  border: 1px solid var(--line);
  background: var(--bg-panel-solid, var(--bg-panel));
  box-shadow: var(--shadow);
}
.mode-switch-top {
  display: flex; justify-content: space-between; align-items: baseline;
  margin-bottom: 10px; padding: 0 2px;
}
.mode-switch-label {
  font-size: 11px;
  letter-spacing: 0.1em;
  text-transform: uppercase;
  color: var(--muted);
  font-weight: 700;
}
.mode-seg { margin: 0; }
.mode-seg button { min-height: 42px; font-weight: 600; font-size: 13px; }
.mode-hint { margin: 0; font-size: 12px; }
.mode-hint strong { color: var(--accent); font-weight: 700; }
.mode-switch-lite { display: grid; gap: 8px; padding: 8px 8px 9px; }
.mode-switch-lite .mode-hint { margin: 0; padding: 0 2px; text-align: center; }

.connect-zone { display: grid; justify-items: center; gap: 14px; padding: 12px 0 6px; }
.connect-btn {
  position: relative;
  width: 158px; height: 158px;
  border: 0; padding: 0; background: transparent; border-radius: 50%;
  transition: transform .25s var(--ease, ease);
}
.connect-btn:hover { transform: scale(1.03); }
.connect-btn:active { transform: scale(0.98); }
.connect-aura {
  position: absolute; inset: 6px; border-radius: 50%;
  background: radial-gradient(circle, color-mix(in srgb, var(--accent) 22%, transparent), transparent 70%);
  opacity: 0; filter: blur(12px);
  transition: opacity .35s ease;
}
.connect-ring {
  position: absolute; inset: 10px; border-radius: 50%;
  border: 1px solid color-mix(in srgb, var(--accent) 22%, var(--line));
  background: transparent;
  box-shadow: inset 0 0 0 1px color-mix(in srgb, var(--text) 4%, transparent);
  transition: border-color .3s ease, box-shadow .3s ease;
}
.connect-arc {
  position: absolute; inset: 10px; border-radius: 50%;
  background: conic-gradient(
    from 210deg,
    transparent 0deg,
    color-mix(in srgb, var(--accent) 0%, transparent) 40deg,
    var(--accent) 110deg,
    var(--accent-2) 150deg,
    transparent 190deg,
    transparent 360deg
  );
  -webkit-mask: radial-gradient(farthest-side, transparent calc(100% - 2px), #000 calc(100% - 1px));
  mask: radial-gradient(farthest-side, transparent calc(100% - 2px), #000 calc(100% - 1px));
  opacity: 0.72;
  transition: opacity .3s ease;
}
.connect-disc {
  position: absolute; inset: 24px; border-radius: 50%;
  display: grid; place-items: center;
  background:
    radial-gradient(circle at 30% 25%, color-mix(in srgb, var(--accent) 10%, transparent), transparent 45%),
    linear-gradient(160deg, color-mix(in srgb, var(--bg-panel-solid, var(--bg-elev)) 92%, #fff), var(--bg-elev));
  border: 1px solid color-mix(in srgb, var(--line) 90%, var(--accent));
  box-shadow: 0 8px 24px rgba(0,0,0,.18);
  transition: border-color .3s ease, box-shadow .3s ease, background .3s ease;
}
.connect-mark {
  font-size: 34px; font-weight: 800; letter-spacing: -0.04em;
  line-height: 1; color: var(--text);
  background: linear-gradient(160deg, var(--text), color-mix(in srgb, var(--accent) 55%, var(--text)));
  -webkit-background-clip: text; background-clip: text;
  color: transparent;
  transition: filter .3s ease, transform .3s ease;
}
.connect-copy { display: grid; justify-items: center; gap: 8px; min-height: 52px; }
.connect-sub { font-size: 12.5px; margin: 0; transition: color .3s ease; }
.connect-meta { display: flex; gap: 8px; align-items: center; }
.connect-meta[hidden] { display: none !important; }
.conn-chip {
  display: inline-flex; align-items: center; gap: 6px;
  padding: 5px 11px; border-radius: 999px;
  font-size: 12px; color: var(--muted);
  background: color-mix(in srgb, var(--accent) 9%, transparent);
  border: 1px solid color-mix(in srgb, var(--accent) 24%, transparent);
}
.conn-chip-k { font-size: 11px; }
.conn-chip strong {
  color: var(--accent); font-family: var(--mono);
  font-size: 12px; font-weight: 600; letter-spacing: 0.01em;
}
.connect-ripple {
  position: absolute; inset: 8px; border-radius: 50%;
  border: 1.5px solid var(--accent);
  opacity: 0; transform: scale(0.9); pointer-events: none;
}
html[data-conn="connected"] .connect-ripple { animation: ripple-out 1s var(--ease, ease) 1 both; }
@keyframes ripple-out {
  0% { opacity: 0.5; transform: scale(0.92); }
  100% { opacity: 0; transform: scale(1.28); }
}
@keyframes aura-breathe {
  0%, 100% { opacity: 0.1; transform: scale(0.97); }
  50% { opacity: 0.3; transform: scale(1.03); }
}
.connect-btn:hover .connect-aura { opacity: 0.35; }
.connect-btn:hover .connect-arc { opacity: 0.95; }
.connect-btn:hover .connect-disc {
  border-color: color-mix(in srgb, var(--accent) 40%, var(--line));
}
html[data-conn="connected"] .connect-aura { opacity: 0.55; }
html[data-conn="connected"] .connect-ring {
  border-color: color-mix(in srgb, var(--accent) 55%, transparent);
  box-shadow:
    0 0 0 1px color-mix(in srgb, var(--accent) 12%, transparent),
    0 0 28px color-mix(in srgb, var(--accent) 18%, transparent);
}
html[data-conn="connected"] .connect-arc {
  opacity: 1;
  animation: arc-spin 10s linear infinite;
}
html[data-conn="connected"] .connect-disc {
  border-color: color-mix(in srgb, var(--accent) 50%, transparent);
  background:
    radial-gradient(circle at 30% 25%, color-mix(in srgb, var(--accent) 18%, transparent), transparent 50%),
    linear-gradient(160deg, color-mix(in srgb, var(--accent) 8%, var(--bg-elev)), var(--bg-elev));
  box-shadow:
    0 0 0 4px color-mix(in srgb, var(--accent) 8%, transparent),
    0 10px 28px rgba(0,0,0,.2);
}
html[data-conn="connected"] .connect-mark {
  background: linear-gradient(160deg, #fff, var(--accent));
  -webkit-background-clip: text; background-clip: text;
  filter: drop-shadow(0 0 10px color-mix(in srgb, var(--accent) 35%, transparent));
}
html[data-conn="connecting"] .connect-arc {
  opacity: 1;
  animation: arc-spin 1.2s linear infinite;
}
html[data-conn="connecting"] .connect-aura { opacity: 0.4; }
html[data-conn="connecting"] .connect-mark {
  background: linear-gradient(160deg, var(--accent-2), var(--accent));
  -webkit-background-clip: text; background-clip: text;
}
@keyframes arc-spin { to { transform: rotate(360deg); } }
@keyframes pulse { 50% { transform: scale(1.04); opacity: .7; } }
@keyframes spin { to { transform: rotate(360deg); } }
.logo-mark {
  display: grid; place-items: center;
  width: 42px; height: 42px; border-radius: 12px;
  background: linear-gradient(135deg, var(--accent-2), var(--accent));
  color: #fff; font-weight: 800;
}
.logo-mark.xl { width: 72px; height: 72px; font-size: 28px; margin: 0 auto; }
.connect-status { font-size: 19px; font-weight: 700; letter-spacing: .01em; }
html[data-conn="connected"] .connect-status { color: var(--ok); }
.delay-pill {
  display: flex; gap: 8px; align-items: center;
  padding: 6px 12px; border-radius: 999px;
  background: color-mix(in srgb, var(--accent) 12%, transparent);
  color: var(--accent); font-size: 12px; font-weight: 600;
}
.home-stats {
  display: grid; grid-template-columns: repeat(3, 1fr); gap: 0;
  width: 100%;
  border: 1px solid var(--line);
  border-radius: 14px;
  overflow: hidden;
  background: var(--bg-panel-solid, var(--bg-panel));
}
.stat {
  background: transparent; border: 0; border-radius: 0; padding: 12px 10px; text-align: center;
  border-right: 1px solid var(--line);
}
.stat:last-child { border-right: 0; }
.stat-k { display: block; color: var(--muted); font-size: 11px; margin-bottom: 4px; letter-spacing: 0.04em; }
.stat-v { font-weight: 700; font-size: 13px; font-family: var(--mono); transition: color .3s ease; }
.home-cta { border-style: dashed; background: transparent; }
.node-cta {
  display: flex; justify-content: space-between; align-items: center; gap: 12px;
  padding: 10px 14px; border-radius: 14px; text-align: left;
}
.node-cta:hover { border-color: var(--accent); }
.node-cta-left { display: grid; gap: 2px; min-width: 0; }
.node-cta-kicker { font-size: 11px; color: var(--muted); letter-spacing: 0.05em; }
.node-cta-left strong {
  font-size: 13.5px; letter-spacing: 0.01em;
  white-space: nowrap; overflow: hidden; text-overflow: ellipsis;
}
.node-cta-right { display: inline-flex; align-items: center; gap: 8px; flex: 0 0 auto; }

/* Home layout variants (prototype exploration) */
.variant-bar { display: flex; align-items: center; gap: 10px; margin: -4px 0 16px; }
.variant-tabs {
  display: inline-flex; gap: 4px; padding: 3px;
  border-radius: 999px; border: 1px solid var(--line);
  background: color-mix(in srgb, var(--bg-elev) 60%, transparent);
}
.vtab {
  border: 0; background: transparent; color: var(--muted);
  font-size: 12px; padding: 5px 10px; border-radius: 999px;
  transition: background .18s ease, color .18s ease;
}
.vtab:hover { color: var(--text); }
.vtab.is-active {
  background: color-mix(in srgb, var(--accent) 16%, transparent);
  color: var(--accent); font-weight: 600;
}

.connect-btn.md { width: 118px; height: 118px; }
.connect-btn.md .connect-disc { inset: 18px; }
.connect-btn.md .connect-mark { font-size: 26px; }
.connect-btn.sm { width: 88px; height: 88px; }
.connect-btn.sm .connect-disc { inset: 14px; }
.connect-btn.sm .connect-mark { font-size: 20px; }
.connect-btn.xl { width: 186px; height: 186px; }
.connect-btn.xl .connect-disc { inset: 28px; }
.connect-btn.xl .connect-mark { font-size: 42px; }

.home-b-grid { display: grid; grid-template-columns: 1.15fr 1fr; gap: 14px; max-width: 860px; align-items: stretch; }
.hb-hero { display: grid; justify-items: center; gap: 12px; padding: 24px 18px 18px; align-content: center; }
.hb-copy { min-height: 0 !important; }
.hb-modes { width: 100%; }
.hb-modes button { min-height: 38px; font-size: 12.5px; }
.hb-side { display: grid; gap: 12px; grid-template-rows: repeat(4, minmax(0, 1fr)); }
.hb-card { display: grid; gap: 8px; padding: 14px 16px; align-content: center; }
.hb-ip { letter-spacing: 0.02em; }
.hb-k {
  font-size: 11px; font-weight: 700; color: var(--muted);
  letter-spacing: 0.06em; text-transform: uppercase;
}
.hb-v { font-family: var(--mono); font-weight: 700; font-size: 15px; }
.hb-v.sm { font-size: 13px; }
.hb-row { display: flex; justify-content: space-between; align-items: baseline; gap: 10px; }
.hb-link { text-align: left; color: var(--text); cursor: pointer; width: 100%; }
.hb-link:hover { border-color: var(--accent); }

.hc-banner {
  display: flex; align-items: center; justify-content: space-between;
  gap: 18px; padding: 16px 20px; max-width: 860px;
}
.hc-left { display: flex; align-items: center; gap: 18px; min-width: 0; }
.hc-copy { display: grid; gap: 5px; }
.hc-right { display: grid; gap: 8px; justify-items: end; }
.hc-modes { width: 300px; }
.hc-modes button { min-height: 34px; font-size: 12px; padding: 6px 8px; }
.hc-grid { display: grid; grid-template-columns: repeat(3, 1fr); gap: 12px; max-width: 860px; margin-top: 14px; }

.home-d-stage {
  display: grid; justify-items: center; gap: 18px;
  padding: 20px 0 40px; width: min(420px, 100%); margin: 0 auto;
}
.hd-copy { min-height: 92px; }
.hd-stats { font-family: var(--mono); font-size: 13px; color: var(--muted); display: flex; gap: 16px; }
.hd-modes { display: inline-flex; gap: 6px; }
.hd-modes button {
  border: 1px solid var(--line); background: transparent; color: var(--muted);
  border-radius: 999px; padding: 6px 14px; font-size: 12px;
  transition: border-color .18s ease, color .18s ease, background .18s ease;
}
.hd-modes button:hover { color: var(--text); border-color: var(--line-strong, var(--accent)); }
.hd-modes button.is-active {
  border-color: var(--accent); color: var(--accent);
  background: color-mix(in srgb, var(--accent) 10%, transparent);
}
.hd-node { border: 0; background: transparent; color: var(--muted); font-size: 13px; padding: 6px 10px; }
.hd-node:hover { color: var(--text); }

.eyebrow {
  margin: 0 0 4px;
  font-size: 11px;
  letter-spacing: 0.12em;
  text-transform: uppercase;
  color: var(--muted);
  font-weight: 700;
}
.toolbar-note { margin: -8px 0 12px; font-size: 12px; }
.btn.icon-btn {
  width: 36px; height: 36px; padding: 0;
  display: grid; place-items: center;
  border-radius: 10px; flex: 0 0 auto;
}
.head-nav { align-items: flex-start; }
.form-section-title {
  margin: 4px 0 2px;
  font-size: 12px; font-weight: 700;
  letter-spacing: 0.06em; text-transform: uppercase;
  color: var(--muted);
}
.form-card .form-section-title:first-child { margin-top: 0; }
.form-hint { margin: -4px 0 4px; }
.form-grid-2 { display: grid; grid-template-columns: 1fr 1fr; gap: 12px; }
.check.switch {
  justify-content: space-between;
  padding: 10px 12px;
  border: 1px solid var(--line);
  border-radius: 10px;
  background: color-mix(in srgb, var(--bg-elev) 70%, transparent);
  color: var(--text);
}
.check.switch input { accent-color: var(--accent); width: 16px; height: 16px; }
.tag {
  display: inline-flex; align-items: center;
  padding: 2px 8px; border-radius: 999px;
  font-size: 11px; font-weight: 600;
  background: color-mix(in srgb, var(--muted) 14%, transparent);
  color: var(--muted);
}
.tag-active { background: color-mix(in srgb, var(--accent) 16%, transparent); color: var(--accent); }
.node-badge {
  font-size: 10px; font-weight: 700; letter-spacing: 0.04em;
  padding: 2px 6px; border-radius: 6px;
  background: color-mix(in srgb, var(--accent) 16%, transparent); color: var(--accent);
}
.latency {
  display: inline-flex; align-items: center; gap: 6px;
  font-family: var(--mono); font-size: 12px; font-weight: 600;
  padding: 5px 9px; border-radius: 999px;
  background: color-mix(in srgb, var(--muted) 10%, transparent);
}
.latency-dot { width: 6px; height: 6px; border-radius: 50%; background: currentColor; }
.delay-good, .latency.delay-good { color: var(--ok); background: color-mix(in srgb, var(--ok) 12%, transparent); }
.delay-ok, .latency.delay-ok { color: var(--accent-2, var(--accent)); background: color-mix(in srgb, var(--accent-2, var(--accent)) 12%, transparent); }
.delay-warn, .latency.delay-warn { color: var(--warn, #f0b429); background: color-mix(in srgb, var(--warn, #f0b429) 12%, transparent); }
.profile-row { align-items: flex-start; }
.profile-main { display: grid; gap: 6px; min-width: 0; flex: 1; }
.row-meta { color: var(--muted); font-size: 12px; }
.section-block { margin-top: 8px; }
.section-block + .section-block, .section-block.panel { margin-top: 16px; }
.section-label {
  font-size: 12px; font-weight: 700; letter-spacing: 0.06em;
  text-transform: uppercase; color: var(--muted); margin-bottom: 8px;
}

.chain { display: grid; gap: 0; margin-bottom: 8px; position: relative; }
.chain-node {
  display: grid; grid-template-columns: 28px 1fr; gap: 12px; align-items: center;
  padding: 12px; border-radius: 12px; border: 1px solid transparent; color: var(--muted);
  position: relative;
}
.chain-node + .chain-node::before {
  content: "";
  position: absolute; left: 25px; top: -6px; width: 1px; height: 12px;
  background: var(--line);
}
.chain-step {
  width: 28px; height: 28px; border-radius: 50%;
  display: grid; place-items: center;
  font-family: var(--mono); font-size: 11px; font-weight: 700;
  border: 1px solid var(--line); background: var(--bg-elev); color: var(--muted);
}
.chain-node.on {
  border-color: color-mix(in srgb, var(--accent) 35%, var(--line));
  color: var(--text);
  background: color-mix(in srgb, var(--accent) 8%, transparent);
}
.chain-node.on .chain-step {
  border-color: var(--accent); color: var(--accent);
  background: color-mix(in srgb, var(--accent) 14%, transparent);
}

.log-shell { padding: 0; overflow: hidden; }
.log-toolbar {
  display: flex; justify-content: space-between; align-items: center;
  padding: 10px 14px; border-bottom: 1px solid var(--line);
  background: color-mix(in srgb, var(--bg-elev) 80%, transparent);
}
.log-panel { font-family: var(--mono); font-size: 12px; max-height: 480px; overflow: auto; padding: 8px 0; }
.log-line {
  display: grid; grid-template-columns: 72px 96px 1fr; gap: 10px; align-items: center;
  padding: 8px 14px; border-bottom: 1px solid color-mix(in srgb, var(--line) 45%, transparent);
}
.log-level {
  display: inline-flex; justify-content: center;
  padding: 2px 8px; border-radius: 6px; font-size: 10px; font-weight: 700; letter-spacing: 0.04em;
}
.log-info { color: var(--accent-2, var(--accent)); background: color-mix(in srgb, var(--accent-2, var(--accent)) 12%, transparent); }
.log-ok { color: var(--ok); background: color-mix(in srgb, var(--ok) 12%, transparent); }
.log-warn { color: var(--warn, #f0b429); background: color-mix(in srgb, var(--warn, #f0b429) 12%, transparent); }
.log-msg { color: var(--text); }

.about-card { text-align: center; max-width: 460px; margin: 12px auto 0; padding: 28px 24px; }
.about-logo { margin-bottom: 12px; }
.about-lead { margin: 8px 0 0; }
.about-meta {
  display: grid; grid-template-columns: repeat(3, 1fr); gap: 8px;
  margin: 20px 0 18px; padding: 12px; border-radius: 12px;
  border: 1px solid var(--line); background: color-mix(in srgb, var(--bg-elev) 70%, transparent);
}
.about-meta > div { display: grid; gap: 4px; }
.about-meta .muted { font-size: 11px; }
.about-actions { justify-content: center; }

.modal-choice {
  display: grid !important; gap: 4px; text-align: left; padding: 14px 16px;
}
.modal-choice strong { color: var(--text); }
.form.nested { padding: 12px; border: 1px dashed var(--line); border-radius: 12px; }
.confirm-copy { margin: 0; color: var(--muted); }
.modal-actions { justify-content: flex-end; margin-top: 16px; }
.btn.danger.solid { background: color-mix(in srgb, var(--danger) 16%, transparent); }

.modal {
  position: fixed; inset: 0; background: rgba(0,0,0,.5);
  display: grid; place-items: center; z-index: 40; padding: 20px;
  backdrop-filter: blur(6px);
}
.modal[hidden] { display: none !important; }
.modal-card {
  width: min(440px, 100%); background: var(--bg-elev); color: var(--text);
  border: 1px solid var(--line); border-radius: 16px; box-shadow: var(--shadow);
}
.modal-card.narrow { width: min(360px, 100%); }
.modal-head, .modal-body { padding: 14px 16px; }
.modal-head { display: flex; justify-content: space-between; align-items: center; border-bottom: 1px solid var(--line); }
.modal-head h2 { margin: 0; font-size: 16px; }
.seg { display: grid; grid-template-columns: repeat(3, 1fr); gap: 6px; }
.seg button {
  border: 1px solid transparent; background: color-mix(in srgb, var(--muted) 10%, transparent); color: var(--text);
  border-radius: 10px; padding: 10px 8px;
  transition: background .18s ease, color .18s ease, transform .18s ease;
}
.seg button:hover { background: color-mix(in srgb, var(--accent) 12%, transparent); }
.seg button.is-active { background: var(--accent); color: #041016; border-color: transparent; font-weight: 700; }
[data-theme="instrument"] .seg button.is-active { color: #fff; }

.toast {
  position: fixed; left: 50%; bottom: 28px; transform: translateX(-50%);
  background: var(--text); color: var(--bg); padding: 10px 14px; border-radius: 999px;
  font-size: 13px; z-index: 50; box-shadow: var(--shadow);
}
.toast[hidden] { display: none !important; }

@media (max-width: 860px) {
  .desktop-frame { grid-template-columns: 1fr; height: auto; min-height: 100vh; margin: 0; border-radius: 0; }
  .sidebar { flex-direction: row; flex-wrap: wrap; gap: 8px; }
  .nav { grid-auto-flow: column; grid-auto-columns: max-content; overflow: auto; }
  .settings-grid { grid-template-columns: 1fr; }
  .page { max-width: none; }
}
"""

def main():
    tech = PROTO / "tech"
    inst = PROTO / "instrument"
    (tech / "css").mkdir(parents=True, exist_ok=True)
    (inst / "css").mkdir(parents=True, exist_ok=True)
    (tech / "css" / "tokens.css").write_text(TECH_TOKENS.strip() + "\n", encoding="utf-8")
    (inst / "css" / "tokens.css").write_text(INSTRUMENT_TOKENS.strip() + "\n", encoding="utf-8")

    tech_polish = """
/* Tech polish — selected visual language */
[data-theme="tech"] .sidebar {
  background:
    var(--sidebar-wash),
    linear-gradient(180deg, color-mix(in srgb, var(--bg-elev) 92%, #000), var(--bg-elev));
}
[data-theme="tech"] .sidebar-brand strong {
  font-weight: 800;
  letter-spacing: -0.03em;
}
[data-theme="tech"] .panel,
[data-theme="tech"] .list-row,
[data-theme="tech"] .mode-switch,
[data-theme="tech"] .setting-card,
[data-theme="tech"] .home-stats,
[data-theme="tech"] .log-shell,
[data-theme="tech"] .about-card {
  background: var(--glass);
  backdrop-filter: blur(14px);
  -webkit-backdrop-filter: blur(14px);
}
[data-theme="tech"] .home-cta:hover {
  border-style: solid;
  border-color: var(--accent);
  color: var(--accent);
  background: color-mix(in srgb, var(--accent) 8%, transparent);
}
[data-theme="tech"] .page-home .page-head { margin-bottom: 8px; }
/* Home hero v2 (tech only) */
[data-theme="tech"] .connect-copy { min-height: 88px; gap: 6px; }
html[data-theme="tech"][data-conn="connected"] .connect-sub {
  color: color-mix(in srgb, var(--ok) 55%, var(--muted));
}
html[data-theme="tech"]:not([data-conn="connected"]):not([data-conn="connecting"]) .connect-aura {
  opacity: 0.16;
  animation: aura-breathe 3.8s ease-in-out infinite;
}
[data-theme="tech"] .node-cta {
  background: var(--glass);
  backdrop-filter: blur(14px);
  -webkit-backdrop-filter: blur(14px);
}
[data-theme="tech"] .node-cta:hover {
  background: color-mix(in srgb, var(--accent) 7%, var(--glass));
  box-shadow: var(--glow-soft, none);
}
[data-theme="tech"] .home-stats { position: relative; }
[data-theme="tech"] .home-stats::before {
  content: "";
  position: absolute; top: 0; left: 10%; right: 10%; height: 1.5px;
  background: linear-gradient(90deg, transparent, var(--accent) 32%, var(--accent-2) 68%, transparent);
  opacity: 0; transition: opacity .45s ease;
}
html[data-theme="tech"][data-conn="connected"] .home-stats::before { opacity: 0.9; }
html[data-theme="tech"]:not([data-conn="connected"]) .home-stats .stat-v { color: var(--muted); }
html[data-theme="tech"]:not([data-conn="connected"]) .hb-v { color: var(--muted); }
html[data-theme="tech"][data-conn="connected"] .hd-stats { color: var(--text); }
html[data-theme="tech"][data-conn="connected"] .hb-ip { color: var(--accent); }
[data-theme="tech"] .hb-hero { position: relative; overflow: hidden; }
[data-theme="tech"] .hb-hero::before {
  content: "";
  position: absolute; top: 0; left: 12%; right: 12%; height: 1.5px;
  background: linear-gradient(90deg, transparent, var(--accent) 32%, var(--accent-2) 68%, transparent);
  opacity: 0; transition: opacity .45s ease;
}
html[data-theme="tech"][data-conn="connected"] .hb-hero::before { opacity: 0.9; }
[data-theme="tech"] .page-head h1 { font-weight: 800; }
[data-theme="tech"] .log-line:hover { background: color-mix(in srgb, var(--accent) 5%, transparent); }
[data-theme="tech"] .modal-choice:hover {
  border-color: var(--accent);
  background: color-mix(in srgb, var(--accent) 8%, var(--bg-panel-solid));
}
html[data-theme="tech"][data-color-scheme="light"] .connect-disc {
  background:
    radial-gradient(circle at 30% 25%, color-mix(in srgb, var(--accent) 12%, transparent), transparent 48%),
    linear-gradient(160deg, #ffffff, #f2f6fa);
  box-shadow: 0 10px 28px rgba(16,32,51,.08);
}
html[data-theme="tech"][data-color-scheme="light"] .connect-mark {
  background: linear-gradient(160deg, #102033, var(--accent));
  -webkit-background-clip: text; background-clip: text;
}
@media (prefers-reduced-motion: reduce) {
  *, *::before, *::after {
    animation-duration: 0.01ms !important;
    transition-duration: 0.01ms !important;
  }
}
"""

    (tech / "css" / "app.css").write_text(APP_CSS.strip() + "\n" + tech_polish.strip() + "\n", encoding="utf-8")
    inst_extra = """
/* Instrument denser dashboard feel */
.desktop-frame { border-radius: 8px; }
.page-head h1 { font-size: 20px; letter-spacing: -0.02em; }
.stat, .list-row, .setting-card, .panel { border-radius: 8px; box-shadow: none; backdrop-filter: none; }
.connect-arc { opacity: .85; }
.connect-disc { border-color: var(--accent); box-shadow: none; }
.connect-aura { display: none; }
.home-stats { grid-template-columns: repeat(3, 1fr); width: 100%; }
.stat-v { font-family: var(--mono); }
.main {
  background:
    linear-gradient(var(--bg), var(--bg)),
    linear-gradient(90deg, var(--grid) 1px, transparent 1px),
    linear-gradient(var(--grid) 1px, transparent 1px);
  background-size: auto, 24px 24px, 24px 24px;
}
.setting-card { box-shadow: none; }
.nav-ico { border-radius: 4px; }
"""
    (inst / "css" / "app.css").write_text(APP_CSS.strip() + "\n" + inst_extra.strip() + "\n", encoding="utf-8")
    (tech / "index.html").write_text(html_doc("tech", "LisaSpeed · Tech 原型"), encoding="utf-8")
    (inst / "index.html").write_text(html_doc("instrument", "LisaSpeed · Instrument 原型"), encoding="utf-8")
    print("OK", tech / "index.html")
    print("OK", inst / "index.html")

if __name__ == "__main__":
    main()
