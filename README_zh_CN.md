# MoonMIME

MoonMIME 是一个以 MoonBit 为主要实现语言、面向不可信 `.eml` 的字节保真 MIME 安全检查与协议测试底层库。它在网关、取证工具或差分测试框架解释内容之前，构建递归实体树、保留原始字节和精确来源区间，并暴露可能造成不同解析器视图分歧的结构歧义。

> 状态：v0.2.0。v0.1.0 已发布至 Mooncakes；v0.2 新增安全审计策略层和可复现量化证据。

## 项目价值与差异

MoonMIME 不再以“又一个通用邮件解析器”为卖点，而是聚焦三类真实接入：邮件导入前的歧义隔离、数字取证的原始证据 sidecar、跨解析器协议差分 oracle。它不做收发信、反病毒或消息生成。场景见 [SECURITY_SCENARIOS.md](docs/SECURITY_SCENARIOS.md)，一手来源与生态边界见 [SECURITY_FORENSICS_EVIDENCE.md](docs/SECURITY_FORENSICS_EVIDENCE.md) 和 [RELATED_WORK.md](docs/RELATED_WORK.md)。

外部研究曾报告 237 个 MIME 候选中 180 个实现了绕过，并产生 448 个跨解析器差分样本；这些是论文数据，不是本项目自测。MoonMIME 当前可复现自测为：六类歧义 60/60 命中、正常基线 20/20 无 finding、10 封公开合成语料 `TP=6 TN=4 FP=0 FN=0`，四个 target 各执行 10,000 个确定性变异且无 panic/挂起。测量范围和限制见 [QUANTITATIVE_EVIDENCE.md](docs/QUANTITATIVE_EVIDENCE.md)。

## 已实现能力

- 有序解析邮件头，保留重复字段及原始顺序；
- 解析嵌套 `multipart/*` 与 `message/rfc822`；
- 保存完整原始输入和半开字节区间；
- 有界解码 Base64、Quoted-Printable；
- 解码 RFC 2047 的 `B`/`Q` encoded-word；
- 解析 RFC 2231 扩展参数及分段参数；
- 严格模式与兼容模式，兼容恢复均产生结构化诊断；
- 枚举附件候选，但不信任附件名、不写出附件；
- 优先选择 `text/plain`，其次选择 `text/html`；
- 输出稳定的 `moonmime.inspect.v1` JSON 和终端摘要；
- 输出稳定的 `moonmime.audit.v1`，每项含严重级别、实体路径和证据字节区间；
- 检测冲突单例头、路径型/可执行附件名、未展开的编码嵌套邮件与非规范恢复；
- `audit --fail-on high` 可直接作为 CI/导入隔离策略，不解码、不落盘附件；
- 核心包可跨后端检查，参考 CLI 仅使用 Native 文件系统适配器。

## 快速使用

安装：`moon add oyjh0381/moonmime@0.2.0`。

```moonbit
///|
test "解析简单邮件" {
  let raw = b"Subject: hello\r\nContent-Type: text/plain\r\n\r\nMoonBit"
  let message = @moonmime.parse(raw)
  inspect(message.root.media_type.essence(), content="text/plain")
}
```

CLI 示例：

```text
moon run --target native cmd/moonmime -- inspect examples/sample.eml --compatible
moon run --target native cmd/moonmime -- inspect examples/sample.eml --compatible --json
moon run --target native cmd/moonmime -- text examples/sample.eml --compatible
moon run --target native cmd/moonmime -- attachments examples/sample.eml --compatible
moon run --target native cmd/moonmime -- audit security-corpus/attack_conflicting_content_type.eml --compatible --json --fail-on high
```

示例文件以仓库文本格式保存，因此命令显式使用兼容模式；生产环境建议先使用默认严格模式。

## 严格模式与兼容模式

严格模式会拒绝邮件头中的非标准换行、缺失闭合边界、重复 MIME 单例字段、未知传输编码、无效 encoded-word 及损坏的传输编码。

兼容模式只接受明确列出的常见偏差，并返回机器可读诊断；不会猜测损坏的 Base64、修复含糊边界或静默替换未知字符集。

## 默认资源限制

- 输入：32 MiB；
- 单个邮件头区：256 KiB；
- 单行邮件头：998 字节；
- 单实体邮件头字段：256 个；
- 嵌套深度：16；
- 实体总数：1,000；
- 单叶原始体与解码体：各 16 MiB；
- 解码总预算：64 MiB；
- 诊断数量：256。

`ResourceLimits` 在解析不可信输入前进行关系校验。

## 明确边界

MoonMIME 不是 SMTP/IMAP 客户端、垃圾邮件或恶意软件扫描器、HTML 清洗器、签名真实性验证器，也不是通用 MIME 生成器。审计 finding 不是恶意概率，零 finding 也不是安全证明；最终隔离策略由调用方决定。项目不自动写出附件。详细信息见 [docs/SCOPE.md](docs/SCOPE.md)、[docs/SECURITY.md](docs/SECURITY.md) 与 [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md)。

## 开发验收

```text
moon check --target all --deny-warn
moon test --target all --deny-warn
moon build --target all
moon fmt --check
moon info
bash scripts/evaluate-security-corpus.sh
moon run --target native --release cmd/moonmime-bench
```

许可证为 Apache-2.0。第三方与标准来源说明见 [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md)。
