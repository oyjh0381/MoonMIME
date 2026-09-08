# MoonMIME

MoonMIME 是一个以 MoonBit 为主要实现语言、带资源上限且保留原始字节的 MIME 邮件解析与检查工具。它以完整 RFC 5322 风格消息的 `Bytes` 为输入，构建递归 MIME 实体树，为每个实体保留源字节区间，并把传输解码、字符集解码与结构解析分离。

> 状态：v0.1.0 发布候选版。GitHub 推送与 mooncakes.io 发布依照项目所有者要求暂缓。

## 项目价值与差异

MoonBit 生态已有面向 HTTP 上传的 `multipart/form-data` 实现；MoonMIME 面向完整 Internet Message 与递归 MIME 实体，覆盖折叠邮件头、`message/rfc822`、Base64、Quoted-Printable、RFC 2047 encoded-word 与 RFC 2231 参数续段。检索证据和功能边界见 [docs/RELATED_WORK.md](docs/RELATED_WORK.md)。

## v0.1 已实现能力

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
- 核心包可跨后端检查，参考 CLI 仅使用 Native 文件系统适配器。

## 快速使用

当前尚未发布 mooncakes 包。本地仓库中的模块名为 `oyjh0381/moonmime`：

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

MoonMIME 不是 SMTP/IMAP 客户端、垃圾邮件或恶意软件扫描器、HTML 清洗器、签名真实性验证器，也不是通用 MIME 生成器。v0.1 不自动写出附件。详细信息见 [docs/SCOPE.md](docs/SCOPE.md)、[docs/SECURITY.md](docs/SECURITY.md) 与 [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md)。

## 开发验收

```text
moon check --target all --deny-warn
moon test --target all --deny-warn
moon build --target all
moon fmt --check
moon info
```

许可证为 Apache-2.0。第三方与标准来源说明见 [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md)。
