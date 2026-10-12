# deploy-ecology-skills

泛微 ecology（E9，Windows 服务器，classbean 部署方式）二开代码部署的 ZCode 技能包：
两个部署技能 + 一套打包 / 安装 / 校验工具。

目标：把「改代码 → 打包 → 部署 → 校验 → 回滚」变成一条可重复、可验证的固定流程。

---

## 第一部分：面向开发者

### 它解决什么问题

在 ecology 上部署二开代码，常见做法是手工拷贝文件。手工做法有五个典型问题：

1. **漏文件。** 内嵌类（`Xxx$Inner.class`）和配置文件（`.properties`）最容易漏，漏一个功能就坏一块。
2. **说不清装了什么。** 没有记录和校验，事后无法证明服务器上是哪个版本。
3. **不敢打包。** 用通配符抓文件，可能把 `wecom.properties` 这类含密钥的文件打进部署包。
4. **难回滚。** 覆盖前没有备份，出问题只能凭记忆恢复。
5. **忘记重启。** ecology 的 Jersey 框架只在服务启动时扫描 `com.cloudstore;com.api` 包。
   拷了类文件不重启，新接口永远返回 404。

本项目把这五件事变成流程里的固定环节。

### 它提供什么能力

两个技能，覆盖从测试到生产的完整路径：

1. **测试环境迭代**（`deploy-ecology-increment`）：每轮只打包本轮变更的文件，装进本机测试
   ecology，装完全量可证。
2. **正式环境上线**（`deploy-ecology-full`）：把项目的完整文件基线打成全量包，一次性迁移到
   正式服务器。安装前有确认门，安装后有审计。

每次部署执行同样的固定动作：

```
写清单 → 打包（逐文件算 SHA256）→ 假根演练（全量流程交付前必过）
      → 安装（备份 → 复制 → 逐个复核哈希）→ 复核（/verify 审计 + 接口探针）
      → 回写基线清单
```

### 核心价值

- **可证部署**：部署包里每个文件带 SHA256。安装后逐个复核，哈希对不上即失败（退出码 1）。
  不存在"以为装好了"。
- **零泄漏**：只打包清单里显式列出的文件，绝不用通配符，含密钥文件不会误入包。
- **可回滚**：每次安装先把旧文件备份到 `_deploy_backup_<时间戳>\`，回滚按原相对路径拷回。
- **可演练**：在纯 ASCII 目录（如 `C:\Temp\`）用假源根 + 假 ecology 根走完整流程——含
  篡改检出（改一个文件后 `/verify` 必须退出码 1），不碰真实环境。
- **对 Agent 友好**：流程固化为技能，每步带完成标准，由 ZCode 会话按步骤执行。
- **实战打磨**：流程来自真实的 ecology 二开部署迭代，配套脚本经假根全流程演练验证。

### 功能清单

配套工具都在 `deploy-kit\`：

| 工具 | 功能 |
|---|---|
| `New-DeployPackage.ps1` | 本地打包：按显式清单收集文件、重算 SHA256、生成可直接拷到服务器的部署包（包内自带安装脚本与说明） |
| `install.bat` | 服务器安装：备份旧文件 → 复制 → `certutil` 逐个复核 SHA256 → 汇总。全部通过退出码 0，任一失败退出码 1 |
| `install.bat <ecology根> /verify` | 审计模式：只校验、不复制，随时核对服务器文件与清单是否一致 |
| `deploy-kit\maps\` | 部署清单目录：含 2 份虚构样例（订单台账），演示清单格式与"内嵌类 / properties 必列"的写法 |

### 适用场景与边界

**适用：**

- 泛微 ecology E9，Windows 服务器，classbean 部署方式。
- 部署物为 class / properties / JSP / 静态资源 / WEB-INF 白名单。
- 需要"测试环境迭代 → 正式环境全量迁移"的标准路径。

**不适用：**

- Linux 服务器、容器化部署、支持热加载的框架。
- 非 ecology 项目。
- 代码版本管理（本项目只管部署这一段）。

### 开始使用

安装只需把 `.agents\` 与 `deploy-kit\` 两个目录复制进你的项目工作区根目录。
首次调用技能时，会弹出一次选择栏确认 ecology 安装根路径；确认后不再询问。

完整安装步骤见第二部分。使用前提、安全红线、FAQ、回滚见
[README-安装说明.md](README-安装说明.md)。

---

## 第二部分：面向 Agent（AI 代理）

本节写给 Agent 开发工具：如何识别本仓库、快速安装技能、并引导用户完成首次初始化。

### 仓库识别

- 本仓库是 ZCode 技能包，技能入口为 `.agents\skills\<技能名>\SKILL.md`。
- 两个技能均标记 `disable-model-invocation: true`：**仅手动触发**。代理不自行调用技能；
  应把技能名告诉用户，由用户点名调用。
- 配套工具在 `deploy-kit\`：打包脚本、服务器安装脚本、部署清单目录（含虚构样例）。

### 快速安装（3 步）

1. 克隆本仓库，把 `.agents\` 与 `deploy-kit\` 复制到用户的项目工作区根目录：

   ```powershell
   git clone https://github.com/Yuzai712/deploy-ecology-skills.git
   cd deploy-ecology-skills
   Copy-Item -Recurse -Force .agents, deploy-kit <工作区根>\
   ```

   `.agents\skills\` 是 ZCode 的技能发现路径，必须位于工作区根。

2. **验证安装**：以下两个文件存在即成功；重启 ZCode 会话后，技能出现在技能列表。

   - `<工作区根>\.agents\skills\deploy-ecology-increment\SKILL.md`
   - `<工作区根>\.agents\skills\deploy-ecology-full\SKILL.md`

3. 引导用户完成首次初始化（见下一节，仅一次）。

### 首次初始化引导（安装后必做）

安装完成后，不要直接开始部署。先让用户完成一次路径确认：

1. 请用户调用任一技能，例如输入技能名 `deploy-ecology-increment`。
2. 技能首次运行会弹出选择栏，询问 ecology 安装根用哪种路径：

   | 选项 | 取值 |
   |---|---|
   | 服务器默认路径（推荐） | `D:\WEAVER\ecology`——ecology 默认安装目录 |
   | 可复用路径 | 用户自定义的安装目录，保存后跨调用复用 |

3. 用户确认后，技能写入 `<工作区根>\deploy-kit\deploy-config.json`。
4. **完成判定**：该文件存在且含 `"confirmed": true`。此后所有调用直接读取配置，不再询问。

说明：`deploy-config.json` 是本机状态，含真实路径，不要提交到版本库（仓库已附 `.gitignore`）。
每个工作区副本初始化一次。

### 项目内全部技能

本项目共 2 个技能，均为仅手动触发：

| 技能 | 何时使用 | 做什么（输入 → 产出） | 调用方式 | 前置条件 | 技能文件 |
|---|---|---|---|---|---|
| `deploy-ecology-increment` | 测试环境每轮迭代：把本轮变更文件装进本机测试 ecology | 变更文件 + 编译产物 → 增量部署包 + 安装与审计结果 + 基线清单更新 | 仅手动（用户点名） | 已完成首次初始化；class 变更时需可用的编译方式（如 IDEA MCP `build_project`） | `.agents\skills\deploy-ecology-increment\SKILL.md` |
| `deploy-ecology-full` | 功能定稿：把整个项目一次性迁到正式环境服务器 | 项目档案（源根 / 基线清单 / 输出目录 / 部署物构成）→ 全量部署包 + 服务器安装与审计 + 回滚锚点 + 部署报告 | 仅手动（用户点名） | 项目已在技能内「项目档案」注册；服务器 ecology 根已明确；重启窗口已获批（重启会清空在线会话） | `.agents\skills\deploy-ecology-full\SKILL.md` |

### 术语与扩展阅读

- `GLOSSARY.md`——项目术语表（清单、基线清单、输出目录、首跑配置、演练等）。读技能前先读它。
- `docs\adr\`——设计决策记录（例如首跑路径配置的取舍）。
- `README-安装说明.md`——完整安装说明。
- `deploy-kit\README.txt`——工具包使用说明（打包 / 安装 / 审计 / 回滚细节）。

---

## 运行环境

- Windows + PowerShell 5.1（打包脚本）；`certutil`（系统自带，用于 SHA256 校验）。
- 服务器端只需 `install.bat`，不依赖 PowerShell。
- 编译步骤使用你现有的编译方式（示例：IDEA MCP `build_project`）；本项目不绑定具体 IDE。
