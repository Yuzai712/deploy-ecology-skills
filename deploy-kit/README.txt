================================================================
 ecology 二开部署工具包（打包-替换-校验）使用说明
================================================================

一、工具包用途
----------------------------------------------------------------
本工具包用于泛微 ecology（E9，Windows 服务器）二开代码的标准
化部署。核心目标：全量替换可证。

  打包时：按显式清单收集文件，重新计算每个文件的 SHA256，
          写入 manifest.txt。
  安装时：先备份旧文件，再逐个复制，复制后逐个用 certutil
          复核 SHA256，全部一致才算成功。

历史教训：Jersey 在 webapp 启动时扫描 com.cloudstore / com.api
包，类文件拷贝后若不重启 ecology 服务，新接口永远返回 404。
因此本工具包在每次安装/校验结束都会强制提醒重启服务。


二、目录结构
----------------------------------------------------------------
deploy-kit\
  New-DeployPackage.ps1    本地打包脚本（PowerShell 5.1 兼容）
  install.bat              服务器端安装脚本（纯批处理）
  README.txt               本说明
  maps\                    部署清单（可人工 review）
    order-ledger-increment-sample.map   增量样例清单（虚构示例）
    order-ledger-full-baseline.map      全量基线样例清单（虚构示例）

解压后的部署 zip 结构：
  order-ledger-deploy-<时间戳>.zip
    install.bat            服务器端安装脚本
    README.txt             本说明
    manifest.txt           清单+校验和
    files\                 目标布局（ecology 根下的相对路径）
      classbean\com\...    编译产物按包路径存放
      mobile\...           mobile 文件（如有）
      WEB-INF\...          安全白名单 XML 等（如有）

manifest.txt 格式（UTF-8 无 BOM，正斜杠，大写十六进制）：

  包内相对路径|SHA256大写十六进制
  classbean/com/engine/demo/order/util/OrderConfig.class|3F2A...（64位）


三、本地打包步骤（开发机）
----------------------------------------------------------------
1. 确认编译产物在源根目录，例如：
   D:\DemoRepo\out\production\OrderModule\

2. 编写或修改 maps\ 下的清单文件。每行一条映射：

   源文件相对路径 => 压缩包内路径

   - "=>" 左侧相对源根目录，右侧相对 files\（即 ecology 根下路径）；
   - 分隔符可用 "=>" 或制表符；
   - 以 # 开头的行是注释，空行忽略；
   - 映射规则：源根 com/xxx  ->  包内 classbean/com/xxx
               源根 mobile/xxx ->  包内 mobile/xxx
               源根 WEB-INF/xxx -> 包内 WEB-INF/xxx
   - 安全约定：只打包清单中显式列出的文件，绝不通配符自动抓
     文件，防止误打入 wecom.properties 等含密钥的敏感文件。

3. 执行打包（PowerShell 5.1）：

   cd D:\DemoOA\deploy-kit
   .\New-DeployPackage.ps1 `
       -SourceRoot D:\DemoRepo\out\production\OrderModule `
       -MapFile   .\maps\order-ledger-increment-sample.map `
       -Name      order-ledger-deploy

4. 产出：默认输出到工具包上一级的 deploy\（项目预先指定的输出
   目录），即 D:\DemoOA\deploy\order-ledger-deploy-<时间戳>.zip。
   演练，或项目档案登记了其他输出目录时，才显式传 -OutDir 输出到别处；传了非默认值时
   脚本会打印提示供确认。
   包内含 install.bat、README.txt、manifest.txt、files\。
   打包前会对每个源文件重新计算哈希，保证 manifest 与包内
   文件一致。


四、服务器安装步骤
----------------------------------------------------------------
1. 把 zip 拷贝到 ecology 服务器，解压（例如到 D:\temp\order-ledger）。

2. 进入解压目录，运行（三选一）：

   install.bat                       按 ECOLOGY_ROOT 或默认目录安装
   install.bat D:\WEAVER\ecology     指定 ecology 安装根目录
   install.bat "D:\WEAVER\ecology"   路径含空格时加引号

   目录解析顺序：命令行参数 > 环境变量 ECOLOGY_ROOT >
   默认 D:\WEAVER\ecology（工具默认值）。使用默认值时会打印该值
   并暂停，需按任意键确认。

3. install.bat 自动完成：
   (a) 校验 manifest.txt 与 files 目录存在；
   (b) 把已存在的目标文件先备份到
       <ecology根>\_deploy_backup_<时间戳>\（保留相对路径）；
   (c) 把 files\<包内路径> 复制到 <ecology根>\<包内路径>
       （自动创建多级子目录）；
   (d) 用 certutil -hashfile 校验复制后目标文件的 SHA256 与
       manifest 一致（兼容中文 Windows 的 "SHA256 哈希:" 前缀，
       大小写不敏感比对）；
   (e) 逐文件打印 [OK]/[FAIL]，结尾打印汇总与失败清单；
   (f) 全部通过 exit 0，任一失败 exit 1。

4. 看到汇总为 0 失败后，必须重启 ecology 服务（见第六节）。


五、/verify 审计模式（只校验，不复制、不备份）
----------------------------------------------------------------
   install.bat D:\WEAVER\ecology /verify

用于审计现有部署是否与清单一致：逐文件计算 ecology 根下目标
文件的 SHA256 并与 manifest.txt 比对，全部一致 exit 0，任一
不一致或缺失 exit 1。适合：
  - 部署完成后复核；
  - 定期巡检；
  - 怀疑文件被误删/误改/被其他部署覆盖时。


六、重启提醒（重要）
----------------------------------------------------------------
Jersey 在 webapp 启动时扫描 com.cloudstore / com.api 包，只
拷贝类文件而不重启 ecology 服务，新接口会一直返回 404。

重启命令示例（服务名以 services.msc 中实际名称为准）：

   net stop "ecology"
   net start "ecology"

或在 services.msc 中找到 ecology 服务，右键"重新启动"。
建议：安装完成并看到 0 失败后，先重启服务，再用 /verify
复核一次，最后联调验证接口。


七、回滚方法
----------------------------------------------------------------
每次安装会把已存在的旧文件备份到：

   <ecology根>\_deploy_backup_<时间戳>\

备份目录内保留 ecology 根下的相对路径，例如：

   _deploy_backup_20260101-090000\
     classbean\com\engine\demo\order\util\OrderConfig.class

回滚步骤：
1. 找到要回滚的那次安装对应的 _deploy_backup_<时间戳> 目录；
2. 把其中的文件按相对路径拷回 ecology 根下对应位置
   （可用 xcopy /e /y 整目录覆盖）；
3. 重启 ecology 服务；
4. 用 install.bat <ecology根> /verify 复核当前部署状态。

注意：备份只覆盖"本次安装前已存在"的目标文件。首次安装
（目标文件原本不存在）不会产生备份，此类文件无法从备份
回滚，需用旧版本部署包重装。


八、编码与兼容性说明
----------------------------------------------------------------
install.bat 以 GBK（ANSI，cp936）编码、CRLF 行尾打包，这是
中文 Windows 批处理的标准形式，在中文 Windows Server 上可直接
双击或命令行运行，中文提示显示正常。manifest.txt 为 UTF-8 无
BOM、LF 行尾，便于跨平台工具核对。

本机 review 时：install.bat 请用支持 GBK 的编辑器打开
（VS Code、Notepad++ 会自动识别，旧版记事本也可直接打开）；
README.txt 与 manifest.txt 为 UTF-8。

New-DeployPackage.ps1 打包时会把 install.bat 强制转为
GBK + CRLF，因此即使源文件被 git autocrlf 等改成 LF 或 UTF-8，
打出来的包依然正确。


九、首次调用与路径配置（deploy-config.json）
----------------------------------------------------------------
配套的两个部署技能（deploy-ecology-increment / deploy-ecology-full）
在首次调用时会弹出选择栏，确认一次 ecology 安装根路径：

  - 服务器默认路径（推荐）：D:\WEAVER\ecology
  - 可复用路径：自定义路径，保存后跨调用复用

确认结果写入 deploy-kit\deploy-config.json（含 confirmed 标记）；
此后所有调用直接读取该配置，不再重复询问。该文件含本机路径，
默认不纳入版本控制（见项目根 .gitignore）。

本工具包的 install.bat 与 New-DeployPackage.ps1 不读取该配置，
只供技能层使用；脚本参数仍以显式传入为准。


十、常见问题
----------------------------------------------------------------
Q: 提示"安装包内文件缺失"怎么办？
A: zip 解压不完整或 manifest 与 files 不一致。重新拷贝 zip
   并完整解压后再运行。install.bat 不会静默跳过缺失文件，
   会直接计入失败并 exit 1。

Q: 校验失败（FAIL 校验不一致）怎么办？
A: 拷贝过程被中断、磁盘错误或目标文件被占用/被改写。重跑
   install.bat 修复；若反复失败，检查目标文件是否被占用、
   磁盘空间是否充足。

Q: 目标路径含空格怎么办？
A: 命令行参数加引号即可，脚本内部所有路径均已加引号处理。

Q: 会不会把 wecom.properties 之类的敏感文件打进去？
A: 不会。打包只认显式清单，不用通配符。请 review maps\ 下
   的清单后再执行打包。

Q: maps\ 里的样例能用吗？
A: 两份样例（order-ledger-*）是纯虚构示例，只演示清单格式；
   复制改名后按你项目的实际文件逐个改写。

================================================================
