# deploy-ecology 双 skill 工具包（v2.0.1）

泛微 ecology（E9，Windows 服务器，classbean 部署方式）二开代码部署的两个 ZCode skill
及其配套工具，源自实战流程（显式清单打包 + SHA256 逐文件校验 + 备份可回滚 + 重启可证），
假根全流程演练通过。

## 包内容

```
.agents\skills\deploy-ecology-increment\SKILL.md   增量部署：测试环境迭代（变更文件出增量包→本机测试 ecology→复核）
.agents\skills\deploy-ecology-full\SKILL.md        全量部署：指定项目完整基线迁移正式环境（基线核对+确认门+审计）
deploy-kit\New-DeployPackage.ps1                   本地打包脚本（PowerShell 5.1 兼容，默认输出到仓库 deploy\）
deploy-kit\install.bat                             服务器端安装脚本 v2.0.1（GBK+CRLF，菜单化：安装/审计/回滚/帮助/退出）
deploy-kit\README.txt                              工具包中文使用说明（打包/安装/审计/回滚/FAQ/编码兼容）
deploy-kit\maps\*.map                              部署清单：2 份虚构样例（订单台账）+ 你的项目清单写这里
```

术语（清单、基线清单、输出目录、随包文件、备份目录、回滚点、操作日志、假根演练等）见
[GLOSSARY.md](GLOSSARY.md)。

## 安装（3 步）

1. 把 `.agents\` 和 `deploy-kit\` 两个目录整体复制到**你的项目工作区根目录**
   （`.agents\skills\` 是 ZCode 的 skill 发现路径，须位于工作区根目录下，即
   `<工作区根>\.agents\skills\`）。
2. **无需手工改任何文件。** 首次调用任一 skill 时，会弹出选择栏让你确认一次
   ecology 安装根路径（ecology 默认安装路径 `D:\WEAVER\ecology` 或自定义路径），
   确认结果保存到 `deploy-kit\deploy-config.json`，之后调用不再询问。注意这是**本机的
   部署目标**（测试 / 演练用）；本机若同时装着生产 ecology，两者必须分开确认。
3. 重启 ZCode 会话（或新开会话），输入 skill 名 `deploy-ecology-increment` 或
   `deploy-ecology-full` 即可调用（两 skill 均为仅手动触发）。

更快的方式：把本仓库路径直接发给 AI 代理，让它自动完成上述复制与验证
（见 README.md「面向 Agent」节的引导话术）。

## 服务器端菜单（install.bat v2.0.1）

服务器上**先解压 zip 到独立文件夹**，再双击 `install.bat`（切勿在压缩软件内直接双击运行）：

| 指令 | 功能 |
|---|---|
| `1` | 安装：`y`=默认路径 `D:\WEAVER\ecology`，或粘贴自定义 ecology 根 |
| `2` | 审计：只核对线上文件与清单，不改动；失败清单写 `logs\verify_fail_<时间戳>.txt` |
| `3` | 回滚：列历史备份点 → 选序号 → 输根目录 → 恢复旧文件，`yes` 确认后删除当次新增文件 |
| `h` | 帮助（浓缩版使用说明） |
| `m` | 返回主菜单并重新播报 |
| `q` | 退出（请用 `q` 退出，不要直接点窗口 X） |

规则要点：

- 清单含 jar 包时先弹警告，须输 `yes` 确认服务已停止，否则中止安装；
- 批量 jar（≥2 个）强制手动输目标路径，不接受默认值；
- 备份落在**解压目录** `_backup\<时间戳>\`（不再放 ecology 根下，避免被扫描影响启动）；
- 全程日志在解压目录 `logs\deploy_<时间戳>.log`（含时间/动作/源路径/目标路径，可手工逆向）；
- 安装/回滚后必须重启 ecology 服务，否则 Jersey 不扫描新类，接口一直 404。

命令行模式（供脚本 / Agent 自动化，无交互）仍保留：
`install.bat <ecology根>`（安装）、`install.bat <ecology根> /verify`（审计），退出码 0/1。
从 Git Bash 调用须抑制参数路径转换，见「使用前提」最后一条。

## 输出目录规则

打包产物最终一律留档到**项目预先指定的输出目录**（约定默认 `<项目工作区>\deploy\`）：
项目登记表 `deploy-kit\projects.md` 为每个项目登记「输出目录」。技能流程显式传 `-OutDir`
先把包落到纯 ASCII 演练目录（规避中文路径的编码风险；全量流程在此完成假根演练），
通过后把 zip 拷回输出目录；打包脚本省略 `-OutDir` 时默认落到工具包上一级的 `deploy\`。

## 使用前提

- Windows + PowerShell 5.1（打包）；`certutil`（SHA256 校验，系统自带）。
- 服务器端 install.bat（菜单/日志/回滚/装前自检）为纯批处理，不依赖 PowerShell。
  请用菜单 `q` 退出而非点窗口 X（脚本无法禁用关闭按钮，仅以常驻提示提醒）。
- 增量 skill 的编译步骤默认用 IDEA MCP `build_project`（仅 class 变更时需要）；
  没有 IDEA MCP 时替换为你们自己的编译方式，完成标准不变（编译成功、无 error，warning 逐条记录）。
- 从 GitHub 下载 zip 解压得到的 `.ps1` 带 MOTW 标记，执行策略受限时改用
  `powershell -NoProfile -ExecutionPolicy Bypass -File .\deploy-kit\New-DeployPackage.ps1 ...`。
- 从 Git Bash 调用 install.bat 时，`/verify` 会被 MSYS 改写成路径——写成整体加引号的
  `MSYS2_ARG_CONV_EXCL='*' cmd /c "install.bat <根> /verify"`；cmd / PowerShell 内直接运行无此问题。
- 不依赖任何外部知识库，skill 自包含可独立运行。

## 安全红线（务必读）

- **绝不通配符打包**：清单必须显式逐个枚举，防止把 wecom.properties 等含密钥文件打进包。
- 内嵌类 `Xxx$Inner.class` 与 `.properties` 是最易漏的两类，存在即必列。
- **命令行模式省略 ecology 根参数时会取 `ECOLOGY_ROOT` 环境变量或默认
  `D:\WEAVER\ecology`，无确认直接安装**（历史上发生过误写事故）。对本机测试环境部署时
  显式传 ecology 根；演练/实验一律用纯 ASCII 目录（如 `C:\Temp\`）下的假根。
- 仅 JSP/静态变更免编译免重启；class 变更必须重启 ecology（Jersey 只在 webapp 启动时
  扫 `com.cloudstore;com.api` 包，不重启 = 新接口永远 404）。
- 正式环境安装前 skill 会走确认门：核对服务器根目录、文件数、备份目录、会话清空四要素。

## 建议的首跑方式

不要直接上真实环境：按 SKILL.md（全量步骤 4；增量「假根演练」节）在纯 ASCII 目录用假源根
+ 假 ecology 根做一次假根演练（出包 → install.bat <假根> → /verify → 篡改一个文件后
/verify 应退出码 1），确认备份/替换/校验/退出码行为符合预期后再实战。
`maps\` 下的两份虚构样例（订单台账）可作格式参考；全量 skill 的项目基线清单
（`<项目>-full-baseline.map`）需在首次全量部署时按项目实际部署物生成定稿。
