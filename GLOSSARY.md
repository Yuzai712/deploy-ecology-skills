# deploy-ecology 部署技能包

泛微 ecology（E9，Windows）二开代码部署的共享词汇：两个技能（增量 / 全量）、打包脚本、
安装脚本与清单体系共同使用。

## 语言

**部署包**：
按清单打包出的 zip，内含 install.bat、README.txt、manifest.txt 与 files\。
_Avoid_：补丁包、发布包

**清单（map）**：
显式逐个枚举「源文件 → 包内路径」映射的文本文件，是"可证部署"的源头。
_Avoid_：文件列表、配置表

**随包文件**：
zip 内固定自带的 install.bat 与 README.txt；清单目标路径与它们重名会被打包脚本拒绝。
_Avoid_：内置文件

**manifest.txt**：
包内文件与各自 SHA256 的对照表；安装与审计（/verify）都以它为准。
_Avoid_：校验单

**基线清单**：
登记项目**全部**部署物的清单，全量迁移的唯一打包依据；增量过程中新增的文件须随时并入。
_Avoid_：全量表、主清单

**项目档案**：
deploy-ecology-full 中登记每个项目信息的表：源根、基线清单、输出目录、部署物构成、最近部署记录。
_Avoid_：项目表

**输出目录**：
项目预先指定、打包产物唯一允许存放的文件夹；约定默认 `<项目工作区>\deploy\`。
_Avoid_：OutDir、导出目录

**首跑配置（deploy-config.json）**：
技能首次调用时经选择栏确认并落盘的路径配置（ecology 安装根），此后调用不再询问。
_Avoid_：路径表

**服务器默认路径**：
ecology 的默认安装目录 `D:\WEAVER\ecology`；首跑确认「ecology 安装根」时的推荐选项。
_Avoid_：默认目录

**可复用路径**：
用户自定义、经一次确认后跨调用复用的 ecology 安装根。
_Avoid_：自定义路径

**演练（假根）**：
用 %TEMP% 下假的源根与 ecology 根走全流程、不碰真实环境的预演方式。
_Avoid_：测试跑
