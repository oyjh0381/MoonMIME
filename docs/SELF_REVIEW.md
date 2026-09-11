# MoonMIME v0.3 本地验收与代码自审

审查基线：2026-09-12；采用 `osc2026-guide` 验收口径，重点复核两个上层集成是否真实、可运行、可复用。

## 【1. 总体评价】

项目已从“解析与审计底层能力”扩展为两条完整交付链：`Bytes → parse/audit → gateway decision → JSONL/exit code` 和 `Bytes → parse/audit → SHA-256 evidence manifest → JSON sidecar`。两个集成均为纯 MoonBit 公共包，平台文件 I/O 只存在于参考 CLI，证明底层库能够被邮件网关和取证案件系统独立复用。

正确性门禁为 56 个 `.mbt` 文件、167 项测试在 Wasm/Wasm-GC/JavaScript/Native 各全通过；两个端到端脚本验证固定决策、退出码、finding code、schema 与哈希。主要剩余风险是完整输入驻留内存、有限字符集和 transfer-encoded `message/rfc822` 仅作为 opaque finding；这些边界均公开，不会静默声称覆盖。

本地结论：代码和材料已实质回应“至少一个代表性上层集成”的复审意见，并额外交付两个案例。组委会结论不可由本地测试保证；GitHub CI、Mooncakes 0.3.0、Gitlink 和报名表仍必须完成外部核验。

## 【2. 算法与性能分析】

- 解析时间最坏 `O(n*d)`、保留空间 `O(n+e)`；默认深度 `d<=16`、实体 `e<=1000`，避免不受控递归。
- 审计对每个实体检查固定 singleton 集合并遍历有界头字段，时间 `O(e*f)`、额外空间 `O(k)`，其中 `f<=256`、`k` 为 finding 数。
- 网关适配器在一次解析/审计后筛选 finding，增加 `O(k+a)` 时间和 `O(k)` 决策数据，`a` 为附件候选数；不解码附件。
- 取证适配器对整封输入和附件原始编码区间执行 SHA-256，时间 `O(n+s)`、SHA 工作内存 `O(1)`（不计已保留输入和输出清单），`s` 为附件区间总长度。区间可能重叠时会重复散列，换取每个证据项可独立验证；默认实体上限下可控。
- 已有 multipart 基准中输入连续扩大 4 倍，median/消息增长 3.22×、3.67×、3.96×。新增集成不是流式实现，不适用于 multi-GiB 邮件；当前没有证据支持为比赛版本引入高复杂度流式状态机。

## 【3. 具体优化步骤】

1. 新增 `integrations/gateway`，把审计 finding 映射为显式、可配置、可解释的 allow/quarantine 决策。
2. 新增批量 JSONL CLI，以退出 0/3 接入 MTA hook、导入队列或 CI，并对读取/解析失败执行 fail-closed reject。
3. 新增 `integrations/forensics`，记录案件/来源、Message-ID、主题、实体路径、字节范围和审计证据。
4. 新增无平台依赖 SHA-256，以三个标准向量跨四后端验证，并绑定整封邮件和附件编码区间。
5. 新增三个无个人数据的协议字节 fixture，以及 Bash/PowerShell 端到端断言；CI 在 Ubuntu/Windows 均执行。
6. 更新 README、架构、范围、测试、场景和专项集成文档，以固定命令、输出和边界替代抽象说明。

## 【4. 推荐修改后的代码】

修改已落实于 `integrations/gateway`、`integrations/forensics`、`internal/sha256`、`cmd/moonmime-gateway`、`cmd/moonmime-forensics` 和 `examples/integrations`。公共接口由 `moon info` 生成并纳入仓库，调用方可直接依赖集成包，也可仅参考 Native CLI 适配层；无需再提供可能漂移的伪代码。

## 【5. 测试建议】

当前已覆盖正常输入、歧义输入、空案件标识、Unicode 来源标识、附件原始区间哈希、SHA-256 单块/多块向量、批量 CLI 决策和跨平台换行稳定性。全量结果：每个 target 167/167；安全语料 `TP=6 TN=4 FP=0 FN=0`；集成证据 `allow=1 quarantine=1 manifests=1 attachments=1 hashes=2`；40,000 次变异零 panic/挂起。

后续值得增加许可证明确的真实脱敏邮件流量回放、10k 邮件批量吞吐和与外部证据库的 sidecar 导入测试。真实邮件可能含敏感信息，未经授权不得进入公开仓库；性能数据必须区分解析、SHA-256 和外部 I/O，避免以合成单文件结果替代生产结论。

## 验收证据

- MoonBit 工具链：moon 0.1.20260827、moonc 0.10.11；高于赛事建议最低版本。
- 规模：约 6,068 行有效 MoonBit、7,070 物理行、56 个 `.mbt` 文件。
- 历史：本次自审提交完成后为 43 条有效提交，均在 2026-04-29 后；申请人、GitHub owner 和主要提交者一致。
- 开源：Apache-2.0；fixture 为公开合成数据；第三方与论文只引用来源，不复制实现。
- 申报书及复审前备份仅本地保存，由 `.gitignore` 与 `.moonignore` 排除。
