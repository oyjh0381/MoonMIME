# MoonMIME 安全、取证与协议测试场景证据

> 证据检索日期：2026-09-11。本文件用于说明 MoonMIME 作为“安全、取证、协议测试底层库”的独立价值。除“MoonMIME 当前能力映射”外，文中的数量均来自所引一手资料；“建议验收指标”是下一轮应实际运行并保存原始结果的目标，不冒充当前测量结果。

## 1. 结论

MoonMIME 不应定位为另一个通用邮件收发库，也不声称自己完成反病毒、垃圾邮件判定或 DKIM/S/MIME 验签。它适合作为这些系统之前的一层**不执行内容、保留原始字节、暴露精确范围、对歧义给出结构化诊断、受资源上限约束的 MIME 结构检查器**。

这个定位有真实且可量化的问题基础：

- CCS 2024 的 MIMEminer 实验覆盖 16 个邮件内容检测器和 7 个客户端，归纳出 24 种绕过方法，其中 19 种为新发现；237 个候选样本中有 180 个至少绕过一个“检测器—客户端”组合，成功率为 75.95%。三类根因正是歧义头、畸形 MIME 结构和解码算法不一致。[论文 DOI](https://doi.org/10.1145/3658644.3670386)，[作者公开全文](https://eki.im/assets/paper/mimeminer-paper.pdf)（访问日期：2026-09-11）。
- IEEE S&P Workshops 2025 的差分模糊测试在 ClamAV、Postfix、SpamAssassin 和 Evolution 的 MIME 解析路径间产生了 448 个差分样本，归并出 15 个根因，其中 3 个能够绕过病毒或垃圾邮件过滤；论文还报告了多个内存破坏问题。[论文 DOI](https://doi.org/10.1109/SPW67851.2025.00007)，[作者公开全文](https://www.cs.ru.nl/~erikpoll/papers/mime2025.pdf)（访问日期：2026-09-11）。
- Go 官方漏洞库记录了 MIME/multipart 对部件、头和内存记账不足导致的拒绝服务，以及 RFC 2047 encoded-word 解码的二次复杂度问题。这说明“总输入字节有限”并不等价于“解析成本有限”。[GO-2023-1569 / CVE-2022-41725](https://pkg.go.dev/vuln/GO-2023-1569)、[GO-2023-1705 / CVE-2023-24536](https://pkg.go.dev/vuln/GO-2023-1705)、[GO-2026-5038 / CVE-2026-42504](https://pkg.go.dev/vuln/GO-2026-5038)（访问日期：2026-09-11）。

因此，MoonMIME 的可审查价值不在“支持多少邮件功能”，而在于能否通过公开语料、恶意变体和性能数据证明以下三个性质：

1. 同一输入不会被静默解释成互相冲突的附件视图；
2. 原始证据及每个结构元素的字节来源可以复核；
3. 深度、实体数、头数量和解码输出等攻击面都有可测的硬上限。

## 2. 真实应用场景与一手证据

### 2.1 安全网关与终端客户端之间的 MIME 解析差异

一封邮件通常会依次经过 MTA、垃圾邮件或恶意内容过滤器、消息存储和最终客户端。若前置过滤器提取的附件集合小于后置客户端展示的附件集合，恶意内容可能未被扫描却被用户下载。MIMEminer 的真实产品实验表明这不是仅存在于语法层的假设：16 个检测器均存在可达成的病毒检测绕过，128 个产品—客户端组合中有 102 个表现出可能导致规避的解析歧义；237 个候选样本中 180 个有效绕过至少一个组合。[CCS 2024 论文](https://eki.im/assets/paper/mimeminer-paper.pdf)（第 6–8 页，访问日期：2026-09-11）。

IEEE 2025 研究进一步给出可复现的开源链路：Postfix 接收邮件，ClamAV 检测 EICAR 测试串，SpamAssassin 检测 GTUBE 测试串，Evolution/Thunderbird 作为终端解释器。研究发现重复 `Content-Transfer-Encoding` 时不同解析器分别采用第一项、第二项、主动尝试 Base64 或根本不解码；重复 `Content-Type` 时也存在首项/末项选择差异。[IEEE 2025 论文](https://www.cs.ru.nl/~erikpoll/papers/mime2025.pdf)（第 5–8 页，访问日期：2026-09-11）。

IETF 当前的防御性工作草案同样把重复/冲突的结构头、无效 boundary、传输解码异常和异常头体分隔列为会改变附件视图的歧义条件，并建议拒绝、隔离或对所有可达视图取并集扫描。该材料是 Internet-Draft，不是已发布标准，因此只作为工程方向证据，不作为规范性合规声明。[draft-chen-email-mime-ambiguity-defense-00](https://www.ietf.org/archive/id/draft-chen-email-mime-ambiguity-defense-00.html)（访问日期：2026-09-11）。

**MoonMIME 当前能力映射：**严格/兼容双模式、按出现顺序保留全部头字段、重复 singleton 诊断、精确 boundary 扫描、稳定诊断代码以及确定性 JSON 报告，可以作为网关的预检层或差分测试 oracle。它输出结构证据，不替代恶意内容扫描器。

### 2.2 重复与冲突头不是普通“容错”，而是安全决策点

RFC 5322 第 3.6 节明确给出头字段出现次数：`Date`、`From`、`Sender`、`Reply-To`、`To`、`Cc`、`Bcc`、`Message-ID`、`Subject` 等最大出现次数为 1；同时要求传输或转换时不应重排头字段。其 obsolete 语法章节还明确说明，多次出现字段的解释通常未定义。[RFC 5322 §3.6](https://www.rfc-editor.org/rfc/rfc5322.html#section-3.6)、[§4.5](https://www.rfc-editor.org/rfc/rfc5322.html#section-4.5)（访问日期：2026-09-11）。

DKIM 又使“顺序和重复次数”成为密码学输入的一部分。RFC 6376 要求 `h=` 中可多次列出同名字段，涉及多个实例时从物理上最后一个实例向上取值；`simple` 头规范化不得改变字段名、空白或字段内容。[RFC 6376 §3.4.1](https://www.rfc-editor.org/rfc/rfc6376.html#section-3.4.1)、[§5.4.2](https://www.rfc-editor.org/rfc/rfc6376.html#section-5.4.2)（访问日期：2026-09-11）。

**MoonMIME 当前能力映射：**`HeaderBlock` 保留字段顺序和字段/值的原始字节范围；安全调用方可以明确实施“重复即拒绝”或“保留全部视图”的策略，而不是让底层 map 覆盖掉证据。MoonMIME v0.1 不执行 DKIM 验签，但能向独立验签器提供不丢序、不丢重复项的输入定位。

### 2.3 multipart boundary 与递归结构是协议歧义高发点

RFC 2046 第 5.1.1 节规定 boundary delimiter 必须位于行首，前导 CRLF 在语义上属于 delimiter，boundary 长度不得超过 70 个字符，匹配候选行时必须进行正确的前缀与结尾判断。第 5.1.2 节进一步要求：解析内层 multipart 时，必须在任何内层深度识别外层 boundary，不能只等待当前层的结束标记。[RFC 2046 §5.1.1](https://www.rfc-editor.org/rfc/rfc2046.html#section-5.1.1)、[§5.1.2](https://www.rfc-editor.org/rfc/rfc2046.html#section-5.1.2)（访问日期：2026-09-11）。

这类细节已经产生实测分歧。IEEE 2025 的 D12（boundary 前额外冒号）、D14（multipart 头中额外引号）和 D15（严重损坏的头/boundary 行）在不同解析器间产生不同实体视图；CCS 2024 也把畸形 MIME 结构列为三大绕过根因之一。[IEEE 2025 论文](https://www.cs.ru.nl/~erikpoll/papers/mime2025.pdf)、[CCS 2024 论文](https://eki.im/assets/paper/mimeminer-paper.pdf)（访问日期：2026-09-11）。

**MoonMIME 当前能力映射：**boundary 仅在物理行首识别，拒绝中缀、相似前缀和非法 closing suffix；递归实体、preamble、epilogue 都保留源范围。协议测试可直接比较实体路径、媒体类型、原始 body 范围和诊断集合，而不必依赖渲染结果。

### 2.4 递归、海量小部件和解码器可造成资源耗尽

Go 官方漏洞报告提供了直接的工程反例：

- CVE-2022-41725 中，`mime/multipart.Reader.ReadForm` 没有完整计算 map 开销、字段名和 MIME 头，并可能创建大量临时文件，使攻击者实际消耗显著超过配置值的内存和 inode。[GO-2023-1569](https://pkg.go.dev/vuln/GO-2023-1569)（访问日期：2026-09-11）。
- CVE-2023-24536 中，大量部件和短生命周期分配造成 CPU、内存及垃圾收集压力；修复后明确限制 `ReadForm` 最多 1000 个部件、每个部件最多 10,000 个头。[GO-2023-1705](https://pkg.go.dev/vuln/GO-2023-1705)（访问日期：2026-09-11）。虽然该入口处理 HTTP form，但它复用了 MIME multipart 数据模型，因此它证明的是通用的“部件数/头数必须单独计费”原则，而不是声称 MoonMIME 受同一实现漏洞影响。
- CVE-2026-42504 表明包含大量无效 encoded-word 的 MIME 头可使 Go 的 `WordDecoder.DecodeHeader` 消耗二次复杂度 CPU。[Go 官方安全公告](https://groups.google.com/g/golang-announce/c/tKs3rmcBcKw)、[GO-2026-5038](https://pkg.go.dev/vuln/GO-2026-5038)（访问日期：2026-09-11）。

实际恶意内容引擎也公开暴露资源边界。ClamAV API 提供“超过最大扫描大小、文件数或递归深度即启发式告警”的选项，并按深度优先顺序调用层级扫描回调。[Cisco Talos ClamAV `clamav.h`](https://github.com/Cisco-Talos/clamav/blob/main/libclamav/clamav.h)（访问日期：2026-09-11）。

**MoonMIME 当前能力映射：**输入、头区、单行、字段数、参数、boundary、递归深度、实体数、body、解码输出和诊断数分别设限；限制在递归或分配前检查。需要用增长曲线和精确 `N/N+1` 测试证明这些声明，而不能只列出配置字段。

### 2.5 字节保真是取证与签名验证的前置条件

RFC 3227 的证据收集最佳实践建议对证据生成校验和或密码学签名，并明确要求过程中不得改变证据；同时要求记录证据如何被发现、处理、保管和移交。[RFC 3227 §3.3.2](https://www.rfc-editor.org/rfc/rfc3227.html#section-3.3.2)、[§4.1](https://www.rfc-editor.org/rfc/rfc3227.html#section-4.1)（访问日期：2026-09-11）。NIST SP 800-86 也要求在备份与成像时维持原始介质/数据的完整性，并建议用消息摘要比较原始数据与副本。[NIST SP 800-86](https://doi.org/10.6028/NIST.SP.800-86)（第 4.2.2 节，访问日期：2026-09-11）。

邮件签名标准对字节边界更敏感：

- DKIM `simple` 头规范化必须按消息中的原样提供字段；正文签名在 MIME transfer encoding 之后、Base64/Quoted-Printable 解码之前计算，并把 MIME 附件包括在签名内容中。[RFC 6376 §3.4](https://www.rfc-editor.org/rfc/rfc6376.html#section-3.4)、[§3.7](https://www.rfc-editor.org/rfc/rfc6376.html#section-3.7)（访问日期：2026-09-11）。
- `multipart/signed` 在传输中必须被视为不透明内容，中间 MTA 不得改变其 content-transfer-encoding 或封装内容。[RFC 1847 §2.1](https://www.rfc-editor.org/rfc/rfc1847.html#section-2.1)（访问日期：2026-09-11）。
- OpenPGP/MIME 的签名覆盖第一部分的内容及其 MIME content headers，CRLF 是否属于签名数据还取决于其与 boundary 的精确位置。[RFC 3156 §5](https://www.rfc-editor.org/rfc/rfc3156.html#section-5)（访问日期：2026-09-11）。

**MoonMIME 当前能力映射：**`InternetMessage.raw` 保存完整输入，头、实体、body、preamble、epilogue 和诊断都用半开字节范围引用同一份证据。解析或展示可以生成派生视图，但原始证据无需通过再序列化重建。v0.1 不负责计算取证哈希或验证签名；推荐由调用方对输入和选定范围计算 SHA-256，并将 MoonMIME JSON 报告作为派生元数据保存。

### 2.6 协议实现需要真实语料和可比较的 oracle

成熟实现的官方测试说明了合理的 oracle 形式：

- MimeKit 官方测试断言多部件消息解析后重新序列化与原始消息完全相同，覆盖空 part、单空行 part、preamble 和 boundary。[MimeKit `MimeMessageTests.cs`](https://github.com/jstedfast/MimeKit/blob/master/UnitTests/MimeMessageTests.cs)（访问日期：2026-09-11）。
- CPython `email.feedparser` 对缺失 boundary、非法 multipart transfer encoding、缺失 closing boundary 等情况产生显式 defect；官方 policy 测试同时验证严格模式抛错与宽容模式记录 defect。[CPython `feedparser.py`](https://github.com/python/cpython/blob/main/Lib/email/feedparser.py)、[`test_policy.py`](https://github.com/python/cpython/blob/main/Lib/test/test_email/test_policy.py)（访问日期：2026-09-11）。
- Apache James Mime4j 官方说明其解析器面向不符合标准的真实邮件采取高度容错策略，并提供流式事件和 DOM 两种视图。[Apache James Mime4j](https://github.com/apache/james-mime4j)（访问日期：2026-09-11）。
- SpamAssassin 官方测试清单含 `badmime`、多个 MIME 样本、Base64、CRLF、DKIM multiple-header 与附件处理语料，可作为“真实生态具有这些回归类别”的佐证。[Apache SpamAssassin `MANIFEST`](https://github.com/apache/spamassassin/blob/trunk/MANIFEST)（访问日期：2026-09-11）。

**MoonMIME 当前能力映射：**稳定 JSON 报告适合把不同实现规约成共同观察量：是否接受、实体树、附件视图、每个 body 的 SHA-256、诊断类别。差分并不自动等于 MoonMIME 错误；RFC 明确、解析器多数行为和安全“取并集/拒绝”策略应分别记录。

## 3. 可复现实验设计

以下实验应由仓库脚本一键生成机器可读结果，固定 MoonMIME commit、MoonBit 版本、操作系统、CPU、参考解析器版本和语料 SHA-256。真实私密邮件不得进入仓库；仅使用自造样本、标准示例、许可允许再分发的上游测试数据，以及 EICAR/GTUBE 官方测试串。

### 实验 A：安全歧义基准集

至少建立 60 个最小 `.eml` fixture，每类不少于 10 个：

1. 重复/冲突 `Content-Type`；
2. 重复/冲突 `Content-Transfer-Encoding`；
3. boundary 行首、中缀、相似前缀、非法后缀、引号及缺失 closing delimiter；
4. 异常折行、裸 CR/LF、NUL 或异常头体分隔；
5. Base64 与 Quoted-Printable 非规范解码；
6. 嵌套 `multipart/*` 与 `message/rfc822` 的深度/外层 boundary 截断。

每个 fixture 必须有人工审定的 RFC 依据、预期 strict 结果、compatible 诊断、实体树和附件 body 哈希。输出 `security-corpus-results.json`，禁止只给截图。

### 实验 B：跨解析器差分

将 MoonMIME、CPython `email`、MimeKit 和 Apache James Mime4j 的结果规约为：

```text
accepted | root media type | ordered entity paths |
attachment count | each attachment SHA-256 | defect/diagnostic classes
```

对实验 A 及至少 100 个许可清晰的正常/畸形样本运行。分类记录：RFC 明确不合规、合法但不同展示策略、错误恢复差异、潜在安全差异。MoonMIME 的核心安全指标是：凡参考解析器出现不同附件哈希集合时，strict 模式必须拒绝，或 compatible 模式必须产生可供上层隔离的歧义诊断；不得静默返回一个“看似唯一”的安全视图。

### 实验 C：字节保真与取证可复核性

对所有基准样本和至少 1000 个固定种子的生成样本：

1. 比较输入 SHA-256 与 `InternetMessage.raw` SHA-256；
2. 验证每个 range 满足 `0 <= start <= end <= raw.length`；
3. 用 raw slice 重取每个头、body、preamble 和 epilogue，并与预期十六进制/哈希比较；
4. 对 `multipart/signed` 标准样例验证“选定 signed part 的原始范围哈希”稳定，不把派生文本或重新序列化结果误当原文；
5. 连续运行三次，JSON 报告（排除明确标注的运行环境字段）逐字节一致。

### 实验 D：资源上限与增长曲线

在 native 目标、固定机器、单进程冷启动/热运行分别测量，至少重复 20 次并报告 median、p95、峰值 RSS：

- 固定深度，输入 64 KiB、256 KiB、1 MiB、4 MiB；
- 固定总字节，实体数 10、100、1000、5000；
- 深度从 1 增至默认上限及 `上限 + 1`；
- 无效 encoded-word 数量 10、100、1000、5000；
- Base64/QP 解码输出恰好为上限和超过上限 1 字节；
- 每一个 ResourceLimits 字段都执行 `N-1/N/N+1` 精确边界测试。

除耗时和内存外，必须记录错误代码、退出码、已创建实体数和诊断数，以证明失败是受控失败而非崩溃、超时或部分成功。

### 实验 E：固定种子变异测试

以实验 A 为种子，对冒号、分号、引号、CR/LF、boundary 字符、encoded-word 标记、Base64 padding 和递归层做确定性变异。每个 target 至少执行 10,000 个输入，记录 seed、输入 SHA-256、结果分类、耗时和失败复现命令。任何 panic、越界、挂起、非确定结果或未受限内存增长均视为失败。

## 4. 建议量化验收指标

这些门槛适合写入申报材料，但只有生成并提交原始报告后才能写成“已达到”：

| 指标 | 建议门槛 | 证明材料 |
|---|---:|---|
| 安全歧义 fixture | `>= 60`，六类各 `>= 10` | fixture 清单、RFC 映射、JSON 结果 |
| strict 危险歧义处置 | 人工标注危险样本 `100%` 拒绝 | 错误代码矩阵 |
| compatible 可观察性 | 被接受的危险/非规范样本 `100%` 至少一个稳定诊断 | 诊断召回率报告 |
| 静默附件视图差异 | `0` | 与 3 个参考解析器的附件哈希集合差分 |
| 原始字节保真 | 全语料及 1000 个生成样本 `100%` 哈希相等 | SHA-256 清单 |
| source range 有效性 | `100%` 范围合法且切片可复核 | range invariant 报告 |
| 资源硬边界 | 每个限制的 `N-1/N/N+1` 行为 `100%` 符合预期 | 限制矩阵 |
| 复杂度增长 | 固定深度时输入扩大 4 倍，median 时间增长目标不超过 5 倍；偏离须解释 | 原始 CSV、机器信息、绘图 |
| 峰值内存 | 1–4 MiB 组中峰值 RSS 与输入保持线性趋势；不得随实体数出现无界跳升 | RSS CSV 与回归拟合 |
| 变异健壮性 | 四 target 各 `>= 10,000` 输入，`0` panic/越界/挂起 | seed、复现命令、汇总 JSON |
| 确定性 | 同版本同输入连续 3 次，结构报告 `100%` 一致 | 报告哈希 |

其中“静默附件视图差异为 0”“原始字节保真 100%”“资源边界 N/N+1 可预测”比单纯增加测试数量更能直接回应初审意见。

## 5. 申报材料中的准确表述边界

建议使用：

> MoonMIME 是面向不可信 `.eml` 的字节保真 MIME 结构检查底层库。它通过严格/兼容双视图、顺序化重复头、精确源范围、稳定歧义诊断和多维资源上限，帮助安全网关、数字取证工具和协议测试框架发现“过滤器所见”与“客户端所见”不一致的风险。项目不承担反病毒、内容净化或身份认证，而是向这些上层系统提供可复核的原始字节与结构证据。

在尚未完成实验前，不应使用“可阻止所有 MIME smuggling”“可验证 DKIM/S/MIME”“达到线性复杂度”或“兼容所有主流客户端”等表述。应把论文数字标明为外部研究结果，把 MoonMIME 的数字绑定到仓库 commit 和公开原始报告。
