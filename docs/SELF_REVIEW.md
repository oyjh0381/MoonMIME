# MoonMIME v0.2 本地验收与代码自审

审查基线：2026-09-11 安全/取证定位改造；采用 `osc2026-guide` 严格门禁。

## 【1. 总体评价】

项目不再只交付通用 MIME 解析能力，而是形成“字节保真解析 → 歧义审计 → 稳定证据报告 → CI 隔离策略”的闭环。真实接入场景、安全研究依据、与现有邮件库的边界以及项目自身测量已分别落到公开文档，直接回应初审意见。

主要风险仍是内存解析、有限字符集和无法递归解释 transfer-encoded `message/rfc822`。v0.2 对最后一项产生 `opaque-embedded-message` finding，而不静默声称已检查。审计规则是结构信号，不是恶意概率；README 已明确零 finding 不等于安全证明。

本地结论：达到重新申报所需的可演示、可复现证据水平。赛事是否通过仍由组委会裁定；Gitlink 同步和更新报名表属于提交环节，需另行确认。

## 【2. 算法与性能分析】

- 头部解析 `O(h)`，递归 MIME 最坏 `O(n*d)`，默认 `d<=16`；保留原文与实体元数据空间 `O(n+e)`。
- audit 对每个实体检查固定的 9 个 singleton 名称并遍历字段，当前上限下为 `O(e*f)`，其中单实体字段 `f<=256`；附件名检查与名称长度线性相关。
- Base64/QP 解码时间和输出空间 `O(b)`，另受单叶与总解码预算约束。
- Native multipart 基准的 64 KiB→256 KiB→1 MiB→4 MiB 连续 4× 放大，median/消息增长 3.22×、3.67×、3.96×，符合该合成形状的近线性预期。完整口径见 `QUANTITATIVE_EVIDENCE.md`。

性能代价：audit 当前为解析后的第二次元数据遍历，换取模块边界清晰和可选调用；在已测吞吐下没有证据支持把它融合进解析器。流式解析可降低峰值内存，但会显著增加 chunk 边界与取证 range 复杂度，暂不实施。

## 【3. 具体优化步骤】

1. 新增 `audit` 深模块，统一 finding code、severity、证据区间和阈值策略。
2. 将重复/冲突单例头、路径型/可执行附件名、非规范换行、兼容恢复和不可展开嵌套邮件变成机器稳定证据。
3. 新增 60 个危险变体、20 个正常控制及 10 封可审阅 `.eml`，防止只用功能描述证明价值。
4. 新增每 target 10,000 次确定性变异，确保畸形输入只返回成功或结构化错误。
5. 新增 in-process 基准并记录环境、median、p95、吞吐和适用边界。
6. 在 Ubuntu/Windows CI 中执行公开语料评估，避免量化结果只在作者机器成立。

## 【4. 推荐修改后的代码】

改造已落到 `audit/audit.mbt`、`audit/render.mbt`、`cmd/moonmime/main.mbt`、`security-corpus/` 与 `scripts/evaluate-security-corpus.*`。接口生成文件通过 `moon info` 更新，格式由 `moon fmt` 统一；不另复制可能漂移的代码片段。

## 【5. 测试建议】

当前 160 项测试在 Wasm、Wasm-GC、JavaScript、Native 全部通过；安全矩阵 60/60 命中、20/20 正常控制无 finding；公开语料 `TP=6 TN=4 FP=0 FN=0`；40,000 次跨 target 变异无 panic/挂起。

后续高价值工作是引入许可证清晰的第三方 MIME corpus，并与 CPython email、MimeKit、Mime4j 做附件哈希集合差分。必须区分 RFC 明确错误、允许的展示策略差异和真正安全差异，不应把“与多数不同”自动判为缺陷。

## 验收证据清单

- 有效 MoonBit 代码约 5,391 行，48 个 `.mbt` 文件，当前 34 条以上有效提交。
- `moon check/test/build --target all --deny-warn`、`moon fmt --check`、`moon info` 均通过。
- GitHub 公开、CI 已配置；v0.1.0 已发布 Mooncakes，v0.2.0 待本轮发布。
- Apache-2.0、中英文 README、示例、稳定 JSON、场景/一手证据/量化文档齐全。
- 申报书为本地管理材料，受 `.gitignore` 与 `.moonignore` 双重排除，不进入 GitHub 或 Mooncakes。
