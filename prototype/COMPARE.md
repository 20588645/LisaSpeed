# LisaSpeed HTML 原型 · 说明

## 选型

**Tech 科技风** 为 Flutter 落地参考：[`tech/index.html`](tech/index.html)

## Flutter 落地（进行中）

已在 `hiddify-app` 落地信息架构第一批：

- 侧栏：**主页 · 节点 · 订阅 · 设置**
- 设置：**通用 · 连接 · 分流 · 高级 · 诊断 · 关于**
- 主页：去掉底部「快速设置」，改为页内连接模式分段

请自行运行桌面「重新编译安装LisaSpeed」验收。

## 信息架构

详见 [`FUNCTION_MAP.md`](FUNCTION_MAP.md)。

## 重新生成 HTML 原型

```bash
python3 prototype/shared/generate_prototypes.py
```
