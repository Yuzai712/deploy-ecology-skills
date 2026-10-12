---
name: deploy-ecology-increment
description: 增量部署（ecology 二开，测试环境每轮迭代）：把本轮变更文件打成增量包、部署到本机测试 ecology 并复核（显式清单 + 逐文件 SHA256 可证）。首次调用会引导确认一次 ecology 安装根路径（存 deploy-kit\deploy-config.json，此后自动跳过）。全量迁移到正式环境请改用 deploy-ecology-full。
disable-model-invocation: true
---

# ecology 二开增量部署（测试环境迭代）

测试环境开发迭代用的部署流程：每轮变更只打增量包，装进本机测试 ecology，
装完全量可证（逐文件 SHA256），class 变更即重启。与全量迁移
（[deploy-ecology-full](../deploy-ecology-full/SKILL.md)）的分工：迭代在测试环境
小步走，功能定稿后走全量流程上生产。

## 工具与路径

工具即本工作区根下的 `deploy-kit\`（与本技能所在的 `.agents\skills\` 同级）：

| 项 | 值 |
|---|---|
| 打包脚本 | `deploy-kit\New-DeployPackage.ps1` |
| 清单目录 | `deploy-kit\maps\`（新清单写这里） |
| 安装脚本 | 随包分发（zip 内自带 install.bat） |
| 测试 ecology 根 | 读 `deploy-kit\deploy-config.json`（首次调用时确认，见步骤 0） |
| 包输出目录 | 项目档案登记的「输出目录」（默认约定 `<项目工作区>\deploy\`；打包先落纯 ASCII 演练目录、通过后拷回；项目档案见 deploy-ecology-full 的「项目档案」表） |
| 项目全量基线 | `deploy-kit\maps\<项目>-full-baseline.map` |

## 步骤 0：路径配置（仅首次调用，之后自动跳过）

读 `deploy-kit\deploy-config.json`：

- **已存在且 `"confirmed": true`** → 取 `ecologyRoot.path` 作为测试 ecology 根，直接进入
  下一步。
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

## 假根演练（首次使用或改动流程后；不碰真实 ecology）

在纯 ASCII 目录（如 `C:\Temp\<演练目录>\`）内闭环——清单与包输出落演练目录、根目录用
假根（本节覆盖步骤 2/4 的默认值）：

1. 用假源根写清单 → 打包（`-OutDir` 落演练目录）；
2. 假根安装 → 全 `[OK]`、退出码 0；假根 `/verify` → 退出码 0；
3. **篡改一个文件再 `/verify` → 必须退出码 1**（证明审计在查，而非永远绿灯）；
4. 重装恢复：再装一次 → 安装退出码 0，`/verify` 亦退出码 0。

**完成标准：四步全对（步骤 1 = 脚本无报错、zip 产出、解包行数 = 清单有效行数；篡改那步
必须为 1）；步骤 5 重启、步骤 6 业务探针、步骤 7 回写基线不在假根上执行（/verify 照跑）。**

## 分支判断

看本轮变更物是什么：

- **class / properties 变更** → 需编译（步骤 1）+ 部署后重启（步骤 5）。
- **仅 JSP / 静态资源变更** → 免编译、免重启，从步骤 2 开始。
- **混合变更（class 与 JSP 同轮）** → 按 class 分支处理：编译 + 重启。

拿不准时按 class 分支处理：多走一次重启，代价是清一次会话；漏重启的代价是新代码永不生效。

## 步骤

### 1. 编译（仅 class 变更）

用你的编译方式（如 IDEA MCP `build_project`）编译本轮变更。
**完成标准：编译成功、问题清单为空，且打包所用产物即本次编译输出（陈旧 class 视为未完成）。**

### 2. 写增量清单 `deploy-kit\maps\<项目>-fix-<日期>.map`

每行一条映射：`源文件相对路径(相对源根) => 包内路径(相对 files/，即 ecology 根下相对路径)`，
`#` 开头为注释。映射规则：

- 源根 `com/xxx`（class 与随包加载的 properties）→ 包内 `classbean/com/xxx`
- 源根 `mobile/xxx` → 包内 `mobile/xxx`
- 源根 `WEB-INF/xxx` → 包内 `WEB-INF/xxx`

两条铁律：

- **逐个枚举**：每个变更文件一行、一个不少——漏写的文件没有任何一步能替你发现（脚本只认清单）。
- **易漏两类**：内嵌类 `Xxx$Inner.class` 和 `.properties` 存在即必列。

格式样例见 `deploy-kit\maps\order-ledger-increment-sample.map`——照它头部三个字段的形态写
（源根 / 变更摘要 / 覆盖既有；后者可为"无"）：清单随改动留档，是部署证据的一部分。
**完成标准：本轮每个变更文件都在清单里恰好一行（含内嵌类与 `.properties`），头部三字段齐全。**

### 3. 打包

打包前刷新产物：class 用本次编译输出；生成型产物（由脚本/构建管线产出的 JSP、前端等）
先重跑生成器并跑项目自带校验（静态检查、断言）全绿再打包——产物级缺陷只在运行时暴露，
陈旧或带缺陷的产物打出去就是线上故障。

`-SourceRoot` 指编译产物目录；部署物来源分散时（如 JSP 只在源码树），先按 ecology
目标布局（`classbean\`、`mobile\`、`WEB-INF\`）组装暂存目录，以暂存目录作 `-SourceRoot`。
脚本不拦 `.java`，误指源码目录会把源码打进包。

中文路径在 PowerShell 下有编码风险：暂存目录、打包输出目录与 `-Name` 一律用纯 ASCII
（如 `-OutDir C:\Temp\drill-order-ledger`、`-Name order-ledger-fix3`；用户名含中文时
`%TEMP%` 同样不合格）；产物再拷回项目输出目录，部署与留档同为这一份。

```powershell
cd deploy-kit
.\New-DeployPackage.ps1 -SourceRoot <编译产物目录或暂存目录> `
    -MapFile .\maps\<项目>-fix-<日期>.map -Name <项目简名>-fix<轮次> `
    -OutDir C:\Temp\<演练目录>
```

（传了非默认 `-OutDir`，脚本会打印黄色提示——演练/ASCII 落点属预期，直接继续。）
包名带轮次标识（`fix<轮次>`）；历轮包全部留在项目输出目录、不删除——首次装出的新文件
无法从备份回滚，重装上一轮的包是唯一退路。脚本自校验：清单行格式、目标路径相对且无 `..`、
不与随包文件重名、源文件在源根内、目标路径去重、源文件存在。任一报错先修清单再打。
**完成标准：脚本无报错、zip 产出；解包核对 zip 内 manifest.txt 行数 = 清单有效行数；包内
每个文件 SHA256 == 来源文件当前哈希（生成型产物即重跑生成后的版本）。**

### 4. 安装到测试 ecology

本机测试环境免拷服务器：把 zip 解压到独立目录（如 `C:\Temp\<演练目录>-unpacked\`），在该
目录内执行，显式传步骤 0 确认的 ecology 根：

```
install.bat <步骤 0 确认的 ecology 根>
```

（显式传根目录——默认分支会 `pause` 卡住自动化终端，且会在装有真实 ecology 的机器上写进
真实安装，见红线。）
从 Git Bash 等环境调用批处理注意参数路径转换（如 `MSYS2_ARG_CONV_EXCL='*' cmd /c install.bat <根>`）。
退出码 0 = 全部通过；1 = 有失败（备份失败 / 复制失败 / 校验不一致 / 目标文件不存在 /
包内文件缺失，逐条报错，不静默跳过）。
失败即回滚：从安装时生成的 `_deploy_backup_<时间戳>\` 目录按原相对路径拷回。
**完成标准：退出码 0 且汇总"失败 0 个"，记录备份目录完整路径。**

### 5. 重启测试 ecology（仅 class 变更）

Jersey 只在 webapp 启动时扫描 `com.cloudstore;com.api` 包，类文件拷进 classbean
后不重启就永远不注册——本流程存在的原因。`net stop "ecology"` / `net start "ecology"`
（服务名以 services.msc 实际为准）。重启清会话，提醒相关方重新登录。
**完成标准：`net start` 输出服务已启动且无错误（必要时 `sc query "ecology"` 显示 RUNNING），并已提醒相关方重新登录。**

### 6. 复核

1. 审计：`install.bat <测试 ecology 根> /verify` → 全 `[OK]`、退出码 0。
2. 业务探针：用已登录会话的浏览器打变更接口（fetch + `credentials:'include'`——鉴权
   只认 session，无 token 通道），对照接口文档断言状态码与 `api_status`/`api_errormsg`。
   无现成登录会话时，用可用的浏览器工具（如 agent-browser）打开登录页、由用户完成登录后
   再执行探针；或请用户在其已登录浏览器里执行并把结果贴回。
3. **版本判据**：探针至少断言本轮产物的线上特征（新增 DOM/行为/字段）——否则"通过"可能
   属于旧版本；版本存疑时先在页面内断言这些特征，直接拉页面源可能被登录/门户导航截胡。
**完成标准：/verify 退出码 0 + 探针断言通过（含版本判据）。**
不通过 → 先按回滚流程恢复（见 `deploy-kit\README.txt` §七），保留现场再排查。

### 7. 回写项目全量基线

基线清单 `<项目>-full-baseline.map` 既是本流程的终点，也是全量迁移的输入，分两种情形：

- **基线已存在** → 把本轮新增文件（基线里没有的）并入；仅覆盖既有文件的不动。
- **基线不存在（项目首次迭代，尚未注册）** → 以本轮清单为初稿建立基线，并按
  deploy-ecology-full 的注册流程与用户确认源根、输出目录、部署物构成后落盘，
  此后按上一条维护。

将来全量迁移以基线为打包依据，这里漏并 = 上生产漏文件。
**完成标准：本轮清单里的每个文件都能在基线清单中找到对应行（新增文件差集为空）。**

## 红线

- 在装有真实 ecology 的机器上跑默认目录分支，会写进真实安装（历史上发生过误写事故）。
  对本机测试环境部署时显式传步骤 0 确认的 ecology 根。
- 假根演练一律在纯 ASCII 目录内闭环、不碰真实 ecology（见「假根演练」一节）；真实 ecology
  根、真实服务器、服务重启留给真实部署。

打包/安装的 FAQ、编码兼容说明、回滚细节见 `deploy-kit\README.txt`；术语见工作区根 `GLOSSARY.md`。
