@echo off
setlocal EnableExtensions EnableDelayedExpansion
chcp 936 >nul 2>&1
title ecology 二开部署工具

rem ============================================================
rem  ecology 二开部署安装脚本（纯批处理，不依赖 PowerShell）
rem  用法:
rem    install.bat                      双击 / 无参数 -> 进入交互菜单
rem    install.bat [ecology根]          命令行安装（供自动化调用）
rem    install.bat [ecology根] /verify  命令行审计（供自动化调用）
rem  退出码: 0 = 全部通过；1 = 存在失败或用法/环境错误
rem ============================================================

set "PKGROOT=%~dp0"
set "SCRIPTVER=2.0.1"

rem ---------- 参数解析 ----------
set "ECOROOT="
set "VERIFYONLY=0"
set "ANYARG=0"
:parseargs
if "%~1"=="" goto argsdone
set "ANYARG=1"
if /i "%~1"=="/verify"  ( set "VERIFYONLY=1" & shift & goto parseargs )
if /i "%~1"=="-verify"   ( set "VERIFYONLY=1" & shift & goto parseargs )
if /i "%~1"=="--verify"  ( set "VERIFYONLY=1" & shift & goto parseargs )
if /i "%~1"=="/?"        ( goto usage )
if /i "%~1"=="-h"        ( goto usage )
if /i "%~1"=="help"      ( goto usage )
if /i "%~1"=="--help"    ( goto usage )
set "ECOROOT=%~1"
shift
goto parseargs
:argsdone

rem ---------- 日志初始化 ----------
call :initlog

rem ---------- 分流：菜单 或 命令行 ----------
if "%ANYARG%"=="0" (
    set "LOGMSG=启动完成，进入交互菜单"
    call :log
    goto menu
)

call :resolve_ecoroot_cli
if errorlevel 1 exit /b 1
if "%VERIFYONLY%"=="1" (
    call :run_verify
    exit /b !errorlevel!
) else (
    call :run_install
    exit /b !errorlevel!
)

rem ############################################################
:menu
set "EMPTYN=0"
:menu_top
cls
echo(
echo  ============================================================
echo    ecology 二开部署工具  v%SCRIPTVER%
echo  ============================================================
echo    包目录: !PKGROOT!
echo    日志  : !LOGFILE!
echo  ------------------------------------------------------------
echo    [1] 安装部署    备份旧文件 -^> 复制新文件 -^> 逐个校验
echo    [2] 审计模式    只核对目标文件与清单是否一致，不改动
echo    [3] 回滚        从历史备份点恢复文件
echo    [h] 帮助        查看完整使用说明
echo    [m] 主菜单      重新播报本菜单
echo    [q] 退出        退出本工具
echo  ------------------------------------------------------------
echo    提示: 请勿直接点窗口右上角 X 关闭，请用 q 退出。
echo  ============================================================
echo(
set "CHOICE="
set /p "CHOICE=请输入指令: "
if not defined CHOICE (
    set /a EMPTYN+=1
    if !EMPTYN! gtr 20 (
        echo(
        echo  [提示] 连续多次未读到输入，判定为非交互环境，已退出。
        goto m_quit
    )
    goto menu_top
)
set "EMPTYN=0"
if /i "%CHOICE%"=="1" goto m_install
if /i "%CHOICE%"=="2" goto m_verify
if /i "%CHOICE%"=="3" goto m_rollback
if /i "%CHOICE%"=="h" goto m_help
if /i "%CHOICE%"=="m" goto menu_top
if /i "%CHOICE%"=="q" goto m_quit
echo [提示] 无法识别的指令: !CHOICE!
pause
goto menu_top

:m_install
set "LOGMSG=========== 菜单: 进入安装流程 =========="
call :log
echo(
echo  ---------------- 安装部署 ----------------
call :count_jars
if "!JARCOUNT!" gtr "0" (
    echo.
    echo  !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
    echo   【警告】本次清单包含 !JARCOUNT! 个 jar 包文件。
    echo   替换 jar 前必须停止 ecology 服务，否则文件被占用
    echo   会导致复制失败或服务异常。
    echo  !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
    echo.
    set "JAROK="
    set /p "JAROK=请确认 ecology 服务已停止，输入 yes 继续: "
    if /i not "!JAROK!"=="yes" (
        echo [中止] 未确认服务已停止，安装已取消。
        set "LOGMSG=[ABORT] 用户未确认 jar 服务停止，取消安装"
        call :log
        pause
        goto menu_top
    )
    set "LOGMSG=[CONFIRM] 用户已确认服务停止 jar数=!JARCOUNT!"
    call :log
)
set "ECOROOT="
if "!JARCOUNT!" geq "2" (
    echo.
    echo  【批量 jar 部署】检测到 !JARCOUNT! 个 jar，按安全规则
    echo   必须手动输入目标 ecology 根目录完整路径，不接受默认值。
    echo.
    set /p "ECOROOT=请输入 ecology 根目录（如 D:\WEAVER\ecology）: "
    if "!ECOROOT!"=="" (
        echo [错误] 批量 jar 部署不允许空路径，已取消。
        set "LOGMSG=[ABORT] 批量 jar 部署路径为空"
        call :log
        pause
        goto menu_top
    )
) else (
    echo.
    echo  请输入 ecology 根目录:
    echo    输入 y 回车 = 使用默认路径 D:\WEAVER\ecology
    echo    或直接粘贴/输入自定义完整路径后回车
    echo.
    set /p "ECOROOT=ecology 根目录 [y=默认]: "
    if /i "!ECOROOT!"=="y" set "ECOROOT=D:\WEAVER\ecology"
    if "!ECOROOT!"=="" set "ECOROOT=D:\WEAVER\ecology"
)
set "LOGMSG=[INPUT] 安装目标根目录: !ECOROOT!"
call :log
call :run_install
echo(
echo  ---------------- 安装结束 ----------------
call :show_tail
call :restart_warn
pause
goto menu_top

:m_verify
set "LOGMSG=========== 菜单: 进入审计流程 =========="
call :log
echo(
echo  ---------------- 审计模式 ----------------
echo  请输入要审计的 ecology 根目录:
echo    输入 y 回车 = 使用默认路径 D:\WEAVER\ecology
echo(
set "ECOROOT="
set /p "ECOROOT=ecology 根目录 [y=默认]: "
if /i "!ECOROOT!"=="y" set "ECOROOT=D:\WEAVER\ecology"
if "!ECOROOT!"=="" set "ECOROOT=D:\WEAVER\ecology"
set "LOGMSG=[INPUT] 审计目标根目录: !ECOROOT!"
call :log
call :run_verify
echo(
echo  ---------------- 审计结束 ----------------
call :show_tail
echo(
echo  输入 b 返回主菜单，输入 q 退出:
set "VA="
set /p "VA=指令: "
if /i "!VA!"=="q" goto m_quit
goto menu_top

:m_rollback
set "LOGMSG=========== 菜单: 进入回滚流程 =========="
call :log
call :do_rollback
echo(
pause
goto menu_top

:m_help
cls
call :print_help
echo(
pause
goto menu_top

:m_quit
set "LOGMSG=========== 用户选择退出 =========="
call :log
echo(
echo  日志文件: %LOGFILE%
echo(
echo  感谢使用，即将退出...
endlocal
exit /b 0

:resolve_ecoroot_cli
if "%ECOROOT%"=="" (
    if not "%ECOLOGY_ROOT%"=="" (
        set "ECOROOT=%ECOLOGY_ROOT%"
        set "LOGMSG=[信息] 使用环境变量 ECOLOGY_ROOT: %ECOROOT%"
        call :both
    ) else (
        set "ECOROOT=D:\WEAVER\ecology"
        set "LOGMSG=[注意] 未指定根目录，使用默认: %ECOROOT%"
        call :both
    )
)
for %%I in ("%ECOROOT%") do set "ECOROOT=%%~fI"
if not exist "%ECOROOT%\" (
    set "LOGMSG=[错误] ecology 根目录不存在: %ECOROOT%"
    call :both
    exit /b 1
)
exit /b 0

:run_install
call :precheck || exit /b 1
call :timestamp
call :norm_ecoroot || exit /b 1
call :count_jars
set "LOGMSG=========== 安装开始 目标=!ECOROOT! =========="
call :log
rem 装前自检：逐个核对包内文件与 manifest 是否一致，防"打包后改包"导致的
rem 包内不一致（否则会先复制坏文件、装完才报 FAIL）。
call :selfcheck_payload
if errorlevel 1 exit /b 1
set "BKBASE=%PKGROOT%_backup"
set "BACKUPROOT=!BKBASE!\!TS!"
if not exist "!BACKUPROOT!" mkdir "!BACKUPROOT!"
set "LOGMSG=[备份] 备份根目录: !BACKUPROOT!"
call :both
set "LOGMSG=[BACKUPROOT] !BACKUPROOT!"
call :log
copy /y "%PKGROOT%manifest.txt" "!BACKUPROOT!\_manifest.txt" >nul 2>&1
set "TOTAL=0" & set "PASS=0" & set "FAIL=0" & set "BKCOUNT=0" & set "NEWCOUNT=0"
for /f "usebackq delims=| tokens=1,2" %%A in ("%PKGROOT%manifest.txt") do (
    set "RELPATH=%%A"
    set "EXPECTED=%%B"
    echo !EXPECTED!| findstr /r "^[0-9A-Fa-f][0-9A-Fa-f]*$" >nul
    if errorlevel 1 (
        set "LOGMSG=[错误] manifest.txt 非法行: !RELPATH!"
        call :both
        set "LOGMSG=[ERROR] manifest 非法行 !RELPATH!"
        call :log
        exit /b 1
    )
    set /a TOTAL+=1
    set "WINPATH=!RELPATH:/=\!"
    set "TARGET=!ECOROOT!\!WINPATH!"
    set "SRCFILE=%PKGROOT%files\!WINPATH!"
    if not exist "!SRCFILE!" (
        set "LOGMSG=[FAIL] !RELPATH! 包内文件缺失"
        call :both
        set "LOGMSG=[FAIL] !RELPATH! 包内文件缺失 files\!WINPATH!"
        call :log
        call :markfail "!RELPATH! 包内文件缺失"
    ) else (
        if exist "!TARGET!" (
            for %%D in ("!TARGET!") do set "TGTDIR=%%~dpD"
            set "RELDIR=!TGTDIR:%ECOROOT%\=!"
            set "BKDIR=!BACKUPROOT!\!RELDIR!"
            set "BKDIR=!BKDIR:\\=\!"
            if not exist "!BKDIR!" mkdir "!BKDIR!"
            copy /y "!TARGET!" "!BKDIR!" >nul
            if errorlevel 1 (
                set "LOGMSG=[FAIL] !RELPATH! 备份失败"
                call :both
                set "LOGMSG=[FAIL] !RELPATH! 备份旧文件失败"
                call :log
                call :markfail "!RELPATH! 备份失败"
            ) else (
                set /a BKCOUNT+=1
                set "LOGMSG=[BACKUP] !TARGET! -> !BKDIR!"
                call :log
            )
        ) else (
            set /a NEWCOUNT+=1
            echo !RELPATH!>>"!BACKUPROOT!\_newfiles.txt"
            set "LOGMSG=[NEW] !RELPATH!（新增文件，无备份）"
            call :log
        )
        for %%D in ("!TARGET!") do set "TGTDIR=%%~dpD"
        if not exist "!TGTDIR!" mkdir "!TGTDIR!"
        copy /y "!SRCFILE!" "!TARGET!" >nul
        if errorlevel 1 (
            set "LOGMSG=[FAIL] !RELPATH! 复制失败"
            call :both
            set "LOGMSG=[FAIL] 复制 !SRCFILE! -> !TARGET!"
            call :log
            call :markfail "!RELPATH! 复制失败"
        ) else (
            set "LOGMSG=[COPY] !SRCFILE! -> !TARGET!"
            call :log
            call :hashit "!TARGET!" ACTUAL
            if /i "!ACTUAL!"=="!EXPECTED!" (
                echo [OK]   !RELPATH!
                set /a PASS+=1
            ) else (
                set "LOGMSG=[FAIL] !RELPATH! 校验不一致"
                call :both
                set "LOGMSG=[FAIL] !RELPATH! 校验不一致 实际=!ACTUAL!"
                call :log
                call :markfail "!RELPATH! 校验不一致"
            )
        )
    )
)
set "LOGMSG="
call :both
set "LOGMSG===================== 安装结果汇总 ===================="
call :both
set "LOGMSG=  共 !TOTAL! 个，通过 !PASS!，失败 !FAIL!，备份 !BKCOUNT!，新增 !NEWCOUNT!"
call :both
set "LOGMSG=[SUMMARY] 安装 总=!TOTAL! 过=!PASS! 败=!FAIL! 备份=!BKCOUNT! 新增=!NEWCOUNT!"
call :log
if !FAIL! gtr 0 (
    for /L %%i in (1,1,!FAIL!) do ( set "LOGMSG=  [x] !FAIL_%%i!" & call :both )
    set "LOGMSG=  可从备份目录恢复: !BACKUPROOT!"
    call :both
)
set "LOGMSG=========== 安装结束 失败=!FAIL! =========="
call :log
if !FAIL! gtr 0 (exit /b 1) else (exit /b 0)

:run_verify
call :precheck || exit /b 1
call :norm_ecoroot || exit /b 1
set "LOGMSG=========== 审计开始 目标=!ECOROOT! =========="
call :log
set "TOTAL=0" & set "PASS=0" & set "FAIL=0"
set "VFAILFILE=%PKGROOT%logs\verify_fail_!TS!.txt"
if not exist "%PKGROOT%logs" mkdir "%PKGROOT%logs"
if exist "!VFAILFILE!" del /q "!VFAILFILE!"
for /f "usebackq delims=| tokens=1,2" %%A in ("%PKGROOT%manifest.txt") do (
    set "RELPATH=%%A"
    set "EXPECTED=%%B"
    echo !EXPECTED!| findstr /r "^[0-9A-Fa-f][0-9A-Fa-f]*$" >nul
    if errorlevel 1 (
        set "LOGMSG=[错误] manifest.txt 非法行: !RELPATH!"
        call :both
        set "LOGMSG=[ERROR] manifest 非法行 !RELPATH!"
        call :log
        exit /b 1
    )
    set /a TOTAL+=1
    set "WINPATH=!RELPATH:/=\!"
    set "TARGET=!ECOROOT!\!WINPATH!"
    if exist "!TARGET!" (
        call :hashit "!TARGET!" ACTUAL
        if /i "!ACTUAL!"=="!EXPECTED!" (
            echo [OK]   !RELPATH!
            set /a PASS+=1
        ) else (
            set "LOGMSG=[FAIL] !RELPATH! 校验不一致"
            call :both
            set "LOGMSG=[VERIFY-FAIL] !RELPATH! 实际=!ACTUAL! 期望=!EXPECTED!"
            call :log
            echo !RELPATH! 校验不一致（实际:!ACTUAL! 期望:!EXPECTED!）>>"!VFAILFILE!"
            call :markfail "!RELPATH! 校验不一致"
        )
    ) else (
        set "LOGMSG=[FAIL] !RELPATH! 目标不存在"
        call :both
        set "LOGMSG=[VERIFY-FAIL] !RELPATH! 目标不存在"
        call :log
        echo !RELPATH! 目标文件不存在>>"!VFAILFILE!"
        call :markfail "!RELPATH! 目标不存在"
    )
)
set "LOGMSG="
call :both
set "LOGMSG===================== 审计结果汇总 ===================="
call :both
set "LOGMSG=  共 !TOTAL! 个，通过 !PASS!，失败 !FAIL!"
call :both
set "LOGMSG=[SUMMARY] 审计 总=!TOTAL! 过=!PASS! 败=!FAIL!"
call :log
if !FAIL! gtr 0 (
    for /L %%i in (1,1,!FAIL!) do ( set "LOGMSG=  [x] !FAIL_%%i!" & call :both )
    set "LOGMSG=  失败清单已写: !VFAILFILE!"
    call :both
)
set "LOGMSG=========== 审计结束 失败=!FAIL! =========="
call :log
if !FAIL! gtr 0 (exit /b 1) else (exit /b 0)

:do_rollback
set "BKBASE=%PKGROOT%_backup"
if not exist "!BKBASE!\" (
    echo [提示] 尚未产生任何备份，无可回滚点。
    set "LOGMSG=[ROLLBACK] 无备份目录，取消"
    call :log
    exit /b 0
)
echo(
echo  ---------------- 可回滚点列表 ----------------
set "BKN=0"
for /f "delims=" %%D in ('dir /b /ad /o-n "!BKBASE!\" 2^>nul') do (
    set /a BKN+=1
    set "BK_!BKN!=%%D"
    echo    [!BKN!] %%D
)
if !BKN!==0 (
    echo [提示] 没有可用的回滚点。
    exit /b 0
)
echo  ------------------------------------------------
echo    [b] 返回主菜单
echo(
set "RSEL="
set /p "RSEL=请输入要回滚的序号（或 b 返回）: "
if /i "!RSEL!"=="b" exit /b 0
if "!RSEL!"=="" exit /b 0
if not defined BK_!RSEL! (
    echo [错误] 无效序号: !RSEL!
    exit /b 1
)
set "RBDIR=!BKBASE!\!BK_%RSEL%!"
echo(
echo  已选回滚点: !RBDIR!
set /p "ECOROOT=请输入要恢复到的 ecology 根目录: "
if "!ECOROOT!"=="" (
    echo [错误] 未输入根目录，回滚取消。
    exit /b 1
)
echo !ECOROOT!| findstr /c:"=" >nul && (
    echo [错误] 路径不能包含等号 = : !ECOROOT!
    exit /b 1
)
for %%I in ("!ECOROOT!") do set "ECOROOT=%%~fI"
if not exist "!ECOROOT!\" (
    echo [错误] 目录不存在: !ECOROOT!
    exit /b 1
)
set "LOGMSG=[ROLLBACK] 选择 !RBDIR! 恢复到 !ECOROOT!"
call :log
set "RBOK=0" & set "RBFAIL=0"
for /f "delims=" %%F in ('dir /b /s /a-d "!RBDIR!" 2^>nul') do (
    set "FULL=%%F"
    set "NAME=%%~nxF"
    if /i not "!NAME!"=="_manifest.txt" if /i not "!NAME!"=="_newfiles.txt" (
        set "REL=!FULL:%RBDIR%\=!"
        set "DST=!ECOROOT!\!REL!"
        for %%D in ("!DST!") do set "DSTDIR=%%~dpD"
        if not exist "!DSTDIR!" mkdir "!DSTDIR!"
        copy /y "!FULL!" "!DST!" >nul
        if errorlevel 1 (
            set "LOGMSG=[FAIL] 恢复失败 !REL!"
            call :both
            set "LOGMSG=[ROLLBACK-FAIL] !FULL! -> !DST!"
            call :log
            set /a RBFAIL+=1
        ) else (
            echo [恢复] !REL!
            set "LOGMSG=[ROLLBACK] !FULL! -> !DST!"
            call :log
            set /a RBOK+=1
        )
    )
)
set "DELN=0"
if exist "!RBDIR!\_newfiles.txt" (
    echo.
    echo  以下是当次安装新增的文件，回滚将删除它们：
    for /f "usebackq delims=" %%L in ("!RBDIR!\_newfiles.txt") do echo    [删] %%L
    echo.
    set "DELOK="
    set /p "DELOK=确认删除以上新增文件？输入 yes 确认: "
    if /i "!DELOK!"=="yes" (
        for /f "usebackq delims=" %%L in ("!RBDIR!\_newfiles.txt") do (
            set "WINP=%%L"
            set "WINP=!WINP:/=\!"
            set "DF=!ECOROOT!\!WINP!"
            if exist "!DF!" (
                del /q "!DF!"
                if errorlevel 1 (
                    set "LOGMSG=[FAIL] 删除失败 %%L"
                    call :both
                    set "LOGMSG=[ROLLBACK-DEL-FAIL] !DF!"
                    call :log
                ) else (
                    echo [删除] %%L
                    set "LOGMSG=[ROLLBACK-DEL] !DF!"
                    call :log
                    set /a DELN+=1
                )
            )
        )
    ) else (
        echo [跳过] 未确认，新增文件保留。
        set "LOGMSG=[ROLLBACK] 用户跳过新增文件删除"
        call :log
    )
)
echo(
echo  ---------------- 回滚完成 ----------------
echo   恢复 !RBOK! 个，删除新增 !DELN! 个，失败 !RBFAIL! 个。
set "LOGMSG=[ROLLBACK-SUMMARY] 恢复=!RBOK! 删新增=!DELN! 失败=!RBFAIL!"
call :log
call :restart_warn
exit /b 0

:selfcheck_payload
set "SCBAD=0"
set "SCN=0"
for /f "usebackq delims=| tokens=1,2" %%A in ("%PKGROOT%manifest.txt") do (
    set "RELPATH=%%A"
    set "EXPECTED=%%B"
    set "WINPATH=!RELPATH:/=\!"
    set "SRCFILE=%PKGROOT%files\!WINPATH!"
    set /a SCN+=1
    if not exist "!SRCFILE!" (
        set "LOGMSG=[自检] 包内缺文件: !RELPATH!"
        call :both
        set /a SCBAD+=1
    ) else (
        call :hashit "!SRCFILE!" SCACT
        if /i not "!SCACT!"=="!EXPECTED!" (
            set "LOGMSG=[自检] 包内文件与清单不一致: !RELPATH!"
            call :both
            set /a SCBAD+=1
        )
    )
)
if !SCBAD! gtr 0 (
    set "LOGMSG=[错误] 安装包自检失败：!SCBAD! 个文件与 manifest 不一致。"
    call :both
    set "LOGMSG=[错误] 多为打包后又改过包内文件。请重新打包后再安装，勿手改包内容。"
    call :both
    exit /b 1
)
set "LOGMSG=[自检] 包内 !SCN! 个文件与 manifest 一致。"
call :log
exit /b 0

:precheck
if not exist "%PKGROOT%manifest.txt" ( set "LOGMSG=[错误] 缺少 manifest.txt" & call :both & exit /b 1 )
if not exist "%PKGROOT%files\"      ( set "LOGMSG=[错误] 缺少 files 目录" & call :both & exit /b 1 )
where certutil >nul 2>&1
if errorlevel 1 ( set "LOGMSG=[错误] 未找到 certutil" & call :both & exit /b 1 )
exit /b 0

:norm_ecoroot
if "!ECOROOT!"=="" ( set "LOGMSG=[错误] ecology 根目录为空" & call :both & exit /b 1 )
echo !ECOROOT!| findstr /c:"=" >nul && (
    set "LOGMSG=[错误] 路径不能包含等号 = : !ECOROOT!"
    call :both
    exit /b 1
)
for %%I in ("!ECOROOT!") do set "ECOROOT=%%~fI"
if not exist "!ECOROOT!\" ( set "LOGMSG=[错误] 根目录不存在: !ECOROOT!" & call :both & exit /b 1 )
exit /b 0

:timestamp
set "TS="
for /f %%T in ('wmic os get localdatetime 2^>nul ^| findstr /r "[0-9]"') do (
    if not defined TS for /f "delims=." %%U in ("%%T") do set "TS=%%U"
)
if not defined TS (
    rem wmic 不可用时的回退：按中文 Windows 的 %DATE% ^(yyyy/MM/dd 周X^) 与
    rem %TIME% ^(H:mm:ss.cc^) 取 token 重组 14 位时间戳，小时补零。
    set "DS=" & set "HS=" & set "MS=" & set "SS="
    for /f "tokens=1-3 delims=/ " %%A in ("%DATE%") do set "DS=%%A%%B%%C"
    for /f "tokens=1-3 delims=:. " %%A in ("%TIME%") do (set "HS=%%A" & set "MS=%%B" & set "SS=%%C")
    if 1!HS! lss 20 set "HS=0!HS!"
    set "TS=!DS!!HS!!MS!!SS!"
)
if not defined TS set "TS=0"
set "TS=!TS:~0,14!"
goto :EOF

:count_jars
set "JARCOUNT=0"
if exist "%PKGROOT%manifest.txt" (
    for /f "usebackq delims=| tokens=1" %%A in ("%PKGROOT%manifest.txt") do (
        set "P=%%A"
        if /i "!P:~-4!"==".jar" set /a JARCOUNT+=1
    )
)
goto :EOF

:initlog
if not exist "%PKGROOT%logs" mkdir "%PKGROOT%logs"
call :timestamp
set "LOGFILE=%PKGROOT%logs\deploy_!TS!.log"
echo ============================================================ >>"%LOGFILE%"
echo  ecology 部署工具日志  启动时间=!DATE! !TIME!>>"%LOGFILE%"
echo  包目录=%PKGROOT%>>"%LOGFILE%"
echo ============================================================ >>"%LOGFILE%"
goto :EOF

:log
rem 读调用方设好的 LOGMSG 变量写日志，避免参数里 > & 被解析。
>>"%LOGFILE%" echo [!DATE! !TIME!] !LOGMSG!
goto :EOF

:both
rem 读 LOGMSG 变量：控制台回显 + 写日志，全程不碰参数解析。
if not defined LOGMSG (
    echo(
    >>"%LOGFILE%" echo.
    goto :EOF
)
echo(!LOGMSG!
>>"%LOGFILE%" echo [!DATE! !TIME!] !LOGMSG!
goto :EOF

:show_tail
echo  最近操作日志（完整见 !LOGFILE!）:
echo  ------------------------------------------------------------
set "N=0"
for /f "delims=" %%L in ('type "%LOGFILE%"') do (
    set /a N+=1
    set "TL_!N!=%%L"
)
if !N! gtr 20 (set /a START=!N!-19) else (set "START=1")
for /L %%i in (!START!,1,!N!) do echo   !TL_%%i!
echo  ------------------------------------------------------------
goto :EOF

:restart_warn
echo(
echo  ###########################################################
echo  #   【重要】必须重启 ecology 服务，否则新代码不生效        #
echo  #   Jersey 启动时扫描 com.cloudstore / com.api 包，       #
echo  #   只拷文件不重启，新接口会一直返回 404。                #
echo  #   重启示例: net stop "ecology" 后 net start "ecology"   #
echo  ###########################################################
echo(
goto :EOF

:hashit
set "%~2="
for /f "delims=" %%L in ('certutil -hashfile %1 SHA256 ^| findstr /r "^[0-9A-Fa-f][0-9A-Fa-f]*$"') do (
    if not defined %~2 set "%~2=%%L"
)
if defined %~2 ( for /f "tokens=*" %%X in ("!%~2!") do set "%~2=%%X" )
goto :EOF

:markfail
set /a FAIL+=1
set "FAIL_!FAIL!=%~1"
goto :EOF

:print_help
echo  ============================================================
echo                     使 用 说 明（浓缩版）
echo  ============================================================
echo   本工具用于把 zip 包内 files\ 下的文件安装到 ecology 根目录。
echo(
echo   【菜单指令】
echo     1  安装：y=默认路径 D:\WEAVER\ecology，或输入自定义路径
echo     2  审计：核对线上文件与清单是否一致，不改动
echo     3  回滚：选择历史备份点，把旧文件恢复回去
echo     h  本帮助   m  主菜单   q  退出
echo(
echo   【安装前必读】
echo     - zip 必须先解压到独立文件夹后再运行 install.bat，
echo       切勿在压缩软件里直接双击运行。
echo     - 含 jar 包时必须先停止 ecology 服务并输入 yes 确认。
echo     - 批量 jar（大于等于2 个）强制手动输入目标路径。
echo(
echo   【备份与日志】
echo     - 备份存放: 包目录\_backup\时间戳\（不再放 ecology 根下）
echo     - 日志存放: 包目录\logs\deploy_时间戳.log
echo     - 日志含 时间/动作/源路径/目标路径，可据此手工逆向。
echo(
echo   【安装后必做】
echo     必须重启 ecology 服务（net stop/start "ecology"），
echo     否则 Jersey 不会扫描新类，接口一直 404。
echo  ============================================================
goto :EOF

:usage
echo 用法: install.bat [ecology根目录] [/verify]
echo(
echo   无参数双击        进入交互菜单（推荐）
echo   [ecology根目录]   命令行安装；省略时取 ECOLOGY_ROOT 或默认 D:\WEAVER\ecology
echo   /verify           仅校验模式：不复制、不备份，只核对 SHA256
echo(
echo 示例:
echo   install.bat                       进菜单
echo   install.bat D:\WEAVER\ecology
echo   install.bat D:\WEAVER\ecology /verify
echo(
echo 退出码: 0 = 全部通过；1 = 存在失败或用法/环境错误。
exit /b 1
