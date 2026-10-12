# deploy-ecology 双 skill 工具包（v1.0）

泛微 ecology（E9，Windows 服务器，classbean 部署方式）二开代码部署的两个 ZCode skill
及其配套工具，源自实战流程（显式清单打包 + SHA256 逐文件校验 + 重启可证），假根全流程
演练通过。

## 包内容

```
.agents\skills\deploy-ecology-increment\SKILL.md   增量部署：测试环境迭代（变更文件出增量包→本机测试 ecology→复核）
.agents\skills\deploy-ecology-full\SKILL.md        全量部署：指定项目完整基线迁移正式环境（基线核对+确认门+审计）
deploy-kit\New-DeployPackage.ps1                   本地打包脚本（PowerShell 5.1 兼容，默认输出到项目 deploy\）
deploy-kit\install.bat                             服务器端安装脚本（GBK+CRLF，纯批处理，certutil 校验）
deploy-kit\README.txt                              工具包中文使用说明（FAQ/回滚/编码兼容/首跑配置）
deploy-kit\maps\*.map                              部署清单：2 份虚构样例（订单台账）+ 你的项目清单写这里
```

术语（清单、基线清单、输出目录、随包文件、可证部署、假根演练等）见 [GLOSSARY.md](GLOSSARY.md)。

## 安装（3 步）

1. 把 `.agents\` 和 `deploy-kit\` 两个目录整体复制到**你的项目工作区根目录**
   （`.agents\skills\` 是 ZCode 的 skill 发现路径，须与你的工作区同级）。
2. **无需手工改任何文件。** 首次调用任一 skill 时，会弹出选择栏让你确认一次
   ecology 安装根路径（服务器默认路径 `D:\WEAVER\ecology` 或自定义可复用路径），
   确认结果保存到 `deploy-kit\deploy-config.json`，之后调用不再询问。
3. 重启 ZCode 会话（或新开会话），输入 skill 名 `deploy-ecology-increment` 或
   `deploy-ecology-full` 即可调用（两 skill 均为仅手动触发）。

## 输出目录规则

打包产物最终一律留档到**项目预先指定的输出目录**（约定默认 `<项目工作区>\deploy\`）：
`deploy-ecology-full` 的项目档案为每个项目登记「输出目录」。技能流程显式传 `-OutDir`
先把包落到纯 ASCII 演练目录（规避中文路径的编码风险；全量流程在此完成假根演练），
通过后把 zip 拷回输出目录；打包脚本省略 `-OutDir` 时默认落到工具包上一级的 `deploy\`。

## 使用前提

- Windows + PowerShell 5.1（打包）；`certutil`（SHA256 校验，系统自带）。
- 增量 skill 的编译步骤默认用 IDEA MCP `build_project`（仅 class 变更时需要）；
  没有 IDEA MCP 时替换为你们自己的编译方式，完成标准不变（编译成功、问题清单为空）。
- 不依赖任何外部知识库，skill 自包含可独立运行。

## 安全红线（务必读）

- **绝不通配符打包**：清单必须显式逐个枚举，防止把 wecom.properties 等含密钥文件打进包。
- 内嵌类 `Xxx$Inner.class` 与 `.properties` 是最易漏的两类，存在即必列。
- **install.bat 默认目录分支（D:\WEAVER\ecology）在装有真实 ecology 的机器上会写进真实
  安装**（历史上发生过误写事故）。对本机测试环境部署时显式传 ecology 根；
  演练/实验一律用纯 ASCII 目录（如 `C:\Temp\`）下的假根。
- 仅 JSP/静态变更免编译免重启；class 变更必须重启 ecology（Jersey 只在 webapp 启动时
  扫 `com.cloudstore;com.api` 包，不重启 = 新接口永远 404）。
- 正式环境安装前 skill 会走确认门：核对服务器根目录、文件数、备份目录、会话清空四要素。

## 建议的首跑方式

不要直接上真实环境：按 SKILL.md（全量步骤 4；增量「假根演练」节）在纯 ASCII 目录用假源根
+ 假 ecology 根做一次假根演练（出包 → install.bat <假根> → /verify → 篡改一个文件后
/verify 应退出码 1），确认备份/替换/校验/退出码行为符合预期后再实战。
`maps\` 下的两份虚构样例（订单台账）可作格式参考；全量 skill 的项目基线清单
（`<项目>-full-baseline.map`）需在首次全量部署时按项目实际部署物生成定稿。
