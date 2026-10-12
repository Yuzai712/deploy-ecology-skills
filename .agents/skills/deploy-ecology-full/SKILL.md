---
name: deploy-ecology-full
description: 全量部署（ecology 二开，项目基线迁正式环境）：把指定项目的完整功能基线打包并迁移到服务器（基线完整性核对、安装前确认门、备份可回滚、逐文件 SHA256 审计）。首次调用会引导确认一次 ecology 安装根路径（存 deploy-kit\deploy-config.json，此后自动跳过）。测试环境日常迭代请改用 deploy-ecology-increment。
disable-model-invocation: true
---

# ecology 二开全量部署（指定项目 → 正式环境）

把一个项目功能的完整文件基线一次性迁移到正式环境。与增量迭代
（[deploy-ecology-increment](../deploy-ecology-increment/SKILL.md)）的分工：
迭代在测试环境小步走，功能定稿后走本流程整体上生产。

## 项目档案

新项目注册：按步骤 1 生成并定稿基线清单，登记四项（源根、基线路径、输出目录、部署物构成）
并与用户确认，落盘 `deploy-kit\maps\` 后更新下表。基线落盘才算注册完成。「输出目录」是项目
预先指定的打包产物存放处（约定默认 `<项目工作区>\deploy\`），一经登记即固定，打包一律
输出到它。

| 项目 | 源根（编译产物） | 全量基线清单 | 输出目录 | 部署物构成 | 最近部署 |
|---|---|---|---|---|---|
| 订单台账（示例） | `D:\DemoRepo\out\production\OrderModule` | `deploy-kit\maps\order-ledger-full-baseline.map` | `D:\DemoOA\deploy\` | classbean 类 + properties、mobile JSP、WEB-INF 白名单 XML（如有） | 2026-01-01 · 全量 11 文件 |

## 步骤 0：路径配置（仅首次调用，之后自动跳过）

本步登记**本机** ecology 安装根：两个技能共用这一份配置（供本机测试与演练定位），登记后
不再询问；正式服务器根由第 5 步确认门显式确认，不读它。

读 `deploy-kit\deploy-config.json`：

- **已存在且 `"confirmed": true`** → 直接进入下一步。
- **不存在或未确认** → 用 AskUserQuestion 弹出选择栏，询问 ecology 安装根用哪种路径：

  | 选项 | 取值 |
  |---|---|
  | 服务器默认路径（推荐） | `D:\WEAVER\ecology`——ecology 默认安装目录，多数安装即此值 |
  | 可复用路径 | 自定义路径：用户指定一个安装根，保存后跨调用复用 |

  用户确认后写入以下配置（首次确认即由本流程生成该文件；用户取消则不写、中止流程，下次
  调用仍会询问）：

  ```json
  {
    "version": 1,
    "confirmed": true,
    "confirmedAt": "YYYY-MM-DD HH:mm",
    "ecologyRoot": { "mode": "server-default", "path": "D:\\WEAVER\\ecology" }
  }
  ```

  `ecologyRoot.mode` 二选一：`server-default`（`path` 固定 `D:\WEAVER\ecology`）或
  `reusable`（`path` = 用户指定的安装根）；读取时只用 `ecologyRoot.path`。

**完成标准：配置存在且 `confirmed: true`。**

## 步骤

### 1. 核对基线完整性

全量包的正确性 = 基线清单 == 项目全部部署物。基线清单不存在时，本次按项目档案的
"部署物构成"生成草稿并逐行 review 定稿，存为档案中的基线路径。已存在时逐类核对：

- **classbean**：源根下该项目包路径下全部 class（**含内嵌类 `Xxx$Inner.class`**）
  与 properties——对照源根实际文件清点，漏一个就是生产上少一个类；
- **mobile**：项目全部 JSP/静态资源；
- **WEB-INF**：安全白名单 XML（如有）。

两条铁律：

- **逐个枚举**：照抄整目录会把 wecom.properties 等含密钥文件打进包，每个文件逐行列出。
- **新增须 review**：基线外发现的新文件先人工 review，确认属于本项目再并入。

**完成标准：classbean 与源根实际文件集合一致、mobile 与 WEB-INF 存在即列，逐类清点完毕、每行都能在源根找到对应文件。**

### 2. 编译

全量包必然含 class：用你的编译方式（如 IDEA MCP `build_project`）编译。
**完成标准：编译成功、无问题清单，且打包所用产物即本次编译输出（陈旧 class 视为未完成）。**

### 3. 打全量包

`-SourceRoot` 用项目档案登记的编译产物目录——脚本不拦 `.java`，误指源码目录会把
源码打进包。输出默认落到项目输出目录；演练，或档案登记了其他目录时，显式传 `-OutDir`。

```powershell
cd deploy-kit
.\New-DeployPackage.ps1 -SourceRoot <项目档案登记的源根> `
    -MapFile .\maps\<项目>-full-baseline.map -Name <项目名>-full
```

脚本自校验：清单行格式、目标路径相对且无 `..`、不与随包文件重名、源文件在源根内、
目标路径去重、源文件存在。
**完成标准：zip 产出在项目输出目录、脚本无报错；解包核对 zip 内 manifest.txt 行数 = 基线有效行数。**

### 4. 拷贝到服务器并解压

zip 整包拷贝到 ecology 服务器，解压到服务器上的临时目录（如 `D:\temp\<包名>\`）并进入该目录。
**完成标准：服务器上 manifest.txt 与 files\ 同目录就位。**

### 5. 确认门（安装前，必过）

向用户复述四件事并等明确确认：

1. 服务器 ecology 根目录为 <实际路径>（本次显式传参；默认值 `D:\WEAVER\ecology` 很可能
   正是真实安装，一律不省略传参）；
2. 本次文件数（zip 内 files\ 数量，应等于基线有效行数）与覆盖范围（全量覆盖 = 逐文件替换）；
3. 备份目录将建在 `<ecology根>\_deploy_backup_<时间戳>\`（回滚锚点）；
4. 稍后重启将清空全部在线会话，相关方需重新登录。

**完成标准：用户明确确认后才进入第 6 步。**

### 6. 服务器安装

```
install.bat <服务器ecology根>
```

流程：备份旧文件 → 按 manifest 逐个复制 → certutil 逐文件复核 SHA256 → 汇总。
退出码 0 = 全部通过；1 = 有失败（备份失败 / 复制失败 / 校验不一致 / 目标文件不存在 /
包内文件缺失，逐条报错，不静默跳过）。失败先回滚再排查：从 `_deploy_backup_<时间戳>\`
按原相对路径拷回；排查期间保留备份目录，它是回滚锚点。
**完成标准：退出码 0、汇总"失败 0 个"，记录备份目录完整路径。**

### 7. 重启正式服务（重启前再次确认）

重启前向用户确认一条：将清空全部在线会话，相关方需重新登录；得到明确确认后再执行。

`net stop "ecology"` / `net start "ecology"`（服务名以服务器 services.msc 实际为准）。
Jersey 只在 webapp 启动时扫 `com.cloudstore;com.api` 包，不重启 = 新类永远不注册。
**完成标准：用户确认后服务已重启，且已向相关方发出重新登录提醒。**

### 8. 审计与业务复核

1. 审计：服务器上 `install.bat <服务器ecology根> /verify` → 全 `[OK]`、退出码 0；
2. 业务探针：已登录会话的浏览器打核心接口（fetch + `credentials:'include'`——鉴权
   只认 session，无 token 通道），断言状态码与 `api_status`/`api_errormsg`；
   无现成登录会话时，用可用的浏览器工具（如 agent-browser）打开登录页、由用户完成登录后
   再执行探针；或请用户在其已登录浏览器里执行并把结果贴回。
**完成标准：/verify 退出码 0 + 核心接口断言通过。**
不通过 → 先按回滚流程恢复（见 `deploy-kit\README.txt` §七），保留现场再排查。

### 9. 报告

向用户报告四项：包名与文件数、服务器 ecology 根、备份目录完整路径（回滚锚点）、审计与
探针结果。
**完成标准：四项已报告；本次记录（清单文件名、部署时间、服务器根、备份目录）已写回项目档案的「最近部署」列。**

## 回滚

从 `_deploy_backup_<时间戳>\` 按原相对路径拷回 → 重启服务 → `/verify` 复核。
注意：备份只含"安装前已存在"的目标文件，首次安装的新文件需用旧版本包重装。
细节见 `deploy-kit\README.txt` §七。

## 红线

- 正式环境一律显式传服务器实际 ecology 根：默认值 `D:\WEAVER\ecology` 很可能正是真实安装
  目录，跑默认分支会先 `pause` 等按键、继而直接写进真实安装（历史上发生过误写事故）。
- 基线外文件一律先人工 review 再并入（见步骤 1）；清单永远逐行显式，不照抄目录。
- 演练全程在 `%TEMP%\<演练目录>\` 内闭环（假源根 + 假 ecology 根，清单、包输出、解压目录
  一并落该目录，用假根跑 install.bat 与 /verify）；服务器拷贝与正式服务重启留给真实部署。

打包/安装的 FAQ、编码兼容说明、回滚细节见 `deploy-kit\README.txt`；术语见工作区根 `GLOSSARY.md`。
