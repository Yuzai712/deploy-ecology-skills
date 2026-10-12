@echo off
setlocal EnableExtensions EnableDelayedExpansion
chcp 936 >nul 2>&1

rem ============================================================
rem  ecology 二开部署安装脚本（纯批处理，不依赖 PowerShell）
rem  用法: install.bat [ecology根目录] [/verify]
rem  退出码: 0 = 全部通过；1 = 存在失败或用法/环境错误
rem ============================================================

set "PKGROOT=%~dp0"

rem ---------- 参数解析 ----------
set "ECOROOT="
set "VERIFYONLY=0"
:parseargs
if "%~1"=="" goto argsdone
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

echo.
echo ============================================================
echo   ecology 二开部署安装工具 v1.0
echo ============================================================

rem ---------- 解析 ecology 根目录 ----------
if "%ECOROOT%"=="" (
    if not "%ECOLOGY_ROOT%"=="" (
        set "ECOROOT=%ECOLOGY_ROOT%"
        echo [信息] 使用环境变量 ECOLOGY_ROOT 指定的根目录: %ECOROOT%
    ) else (
        set "ECOROOT=D:\WEAVER\ecology"
        echo [注意] 未指定 ecology 根目录，也未设置 ECOLOGY_ROOT 环境变量。
        echo [注意] 将使用默认目录: %ECOROOT%
        echo [注意] 如目录不正确，请立即关闭本窗口后重新运行。
        pause
    )
)
for %%I in ("%ECOROOT%") do set "ECOROOT=%%~fI"
if not exist "%ECOROOT%\" (
    echo [错误] ecology 根目录不存在或不是目录: %ECOROOT%
    exit /b 1
)
if "%VERIFYONLY%"=="1" (
    echo [模式] 仅校验模式：不复制、不备份，只核对目标文件与 manifest.txt。
) else (
    echo [模式] 安装模式：先备份旧文件，再复制新文件，最后逐个校验 SHA256。
)
echo [目标] ecology 根目录: %ECOROOT%

rem ---------- 前置检查 ----------
if not exist "%PKGROOT%manifest.txt" (
    echo [错误] 缺少 manifest.txt: %PKGROOT%manifest.txt
    exit /b 1
)
if not exist "%PKGROOT%files\" (
    echo [错误] 缺少 files 目录: %PKGROOT%files
    exit /b 1
)
where certutil >nul 2>&1
if errorlevel 1 (
    echo [错误] 未找到 certutil 命令，无法计算 SHA256 校验和。
    exit /b 1
)

rem ---------- 时间戳与备份目录 ----------
set "TS="
for /f %%T in ('wmic os get localdatetime 2^>nul ^| findstr /r "[0-9]"') do (
    if not defined TS for /f "delims=." %%U in ("%%T") do set "TS=%%U"
)
if not defined TS (
    set "RAW=%DATE% %TIME%"
    set "TS=!RAW:/=!"
    set "TS=!TS:-=!"
    set "TS=!TS::=!"
    set "TS=!TS:.=!"
    set "TS=!TS: =!"
)
if not defined TS set "TS=0"
set "TS=!TS:~0,14!"

if "%VERIFYONLY%"=="0" (
    set "BACKUPROOT=%ECOROOT%\_deploy_backup_!TS!"
    set "BKN=0"
:uniqloop
    if exist "!BACKUPROOT!" (
        set /a BKN+=1
        set "BACKUPROOT=%ECOROOT%\_deploy_backup_!TS!_!BKN!"
        goto uniqloop
    )
    echo [备份] 旧文件备份目录（仅备份已存在的目标文件）: !BACKUPROOT!
)

rem ---------- 主循环：逐行处理 manifest ----------
set "TOTAL=0"
set "PASS=0"
set "FAIL=0"
set "BKCOUNT=0"

for /f "usebackq delims=| tokens=1,2" %%A in ("%PKGROOT%manifest.txt") do (
    set "RELPATH=%%A"
    set "EXPECTED=%%B"

    rem manifest 行完整性校验（哈希须为 64 位十六进制）
    echo !EXPECTED!| findstr /r "^[0-9A-Fa-f][0-9A-Fa-f]*$" >nul
    if errorlevel 1 (
        echo.
        echo [错误] manifest.txt 存在非法行（哈希为空或不是 64 位十六进制）:
        echo        !RELPATH!
        echo [错误] 安装包不完整或 manifest 被篡改，已中止。
        exit /b 1
    )

    set /a TOTAL+=1
    set "WINPATH=!RELPATH:/=\!"
    set "TARGET=!ECOROOT!\!WINPATH!"
    set "SRCFILE=%PKGROOT%files\!WINPATH!"

    if "!VERIFYONLY!"=="1" (
        rem ===== 仅校验模式 =====
        if exist "!TARGET!" (
            call :hashit "!TARGET!" ACTUAL
            if /i "!ACTUAL!"=="!EXPECTED!" (
                echo [OK]   !RELPATH!
                set /a PASS+=1
            ) else (
                echo [FAIL] !RELPATH! 校验不一致（实际: !ACTUAL!）
                call :markfail "!RELPATH! 校验不一致"
            )
        ) else (
            echo [FAIL] !RELPATH! 目标文件不存在
            call :markfail "!RELPATH! 目标文件不存在"
        )
    ) else (
        rem ===== 安装模式 =====
        if not exist "!SRCFILE!" (
            echo [FAIL] !RELPATH! 安装包内文件缺失: files\!WINPATH!
            call :markfail "!RELPATH! 包内文件缺失"
        ) else (
            rem --- 备份已存在的目标文件（保留相对路径）---
            if exist "!TARGET!" (
                for %%D in ("!TARGET!") do set "TGTDIR=%%~dpD"
                set "RELDIR=!TGTDIR:%ECOROOT%\=!"
                set "BKDIR=!BACKUPROOT!\!RELDIR!"
                set "BKDIR=!BKDIR:\\=\!"
                if not exist "!BKDIR!" mkdir "!BKDIR!"
                copy /y "!TARGET!" "!BKDIR!" >nul
                if errorlevel 1 (
                    echo [FAIL] !RELPATH! 备份旧文件失败
                    call :markfail "!RELPATH! 备份失败"
                ) else (
                    set /a BKCOUNT+=1
                    echo [备份] !RELPATH! 已存于 !BKDIR!
                )
            )
            rem --- 复制 ---
            for %%D in ("!TARGET!") do set "TGTDIR=%%~dpD"
            if not exist "!TGTDIR!" mkdir "!TGTDIR!"
            copy /y "!SRCFILE!" "!TARGET!" >nul
            if errorlevel 1 (
                echo [FAIL] !RELPATH! 复制失败
                call :markfail "!RELPATH! 复制失败"
            ) else (
                call :hashit "!TARGET!" ACTUAL
                if /i "!ACTUAL!"=="!EXPECTED!" (
                    echo [OK]   !RELPATH!
                    set /a PASS+=1
                ) else (
                    echo [FAIL] !RELPATH! 校验不一致（实际: !ACTUAL!）
                    call :markfail "!RELPATH! 校验不一致"
                )
            )
        )
    )
)

rem ---------- 汇总 ----------
echo.
echo ============================================================
if "!VERIFYONLY!"=="1" (echo                    校 验 结 果 汇 总) else (echo                    安 装 结 果 汇 总)
echo   共 !TOTAL! 个文件，通过 !PASS! 个，失败 !FAIL! 个。
if "!VERIFYONLY!"=="0" echo   本次备份旧文件 !BKCOUNT! 个。
if !FAIL! gtr 0 (
    echo   失败清单:
    for /L %%i in (1,1,!FAIL!) do echo     [x] !FAIL_%%i!
    echo   如已产生备份，可从 !BACKUPROOT! 恢复后重试。
)
echo ============================================================

rem ---------- 重启提醒 ----------
echo.
echo  ###########################################################
echo  #                                                         #
echo  #   【必须重启 ecology 服务，否则新代码不生效】            #
echo  #                                                         #
echo  #   Jersey 在 webapp 启动时会扫描 com.cloudstore / com.api #
echo  #   包。只拷贝类文件而不重启服务，新接口会一直返回 404。   #
echo  #                                                         #
echo  #   重启命令示例（服务名以 services.msc 中实际名称为准）:   #
echo  #       net stop "ecology"                                #
echo  #       net start "ecology"                               #
echo  #   或打开 services.msc，找到 ecology 服务后右键重启。     #
echo  #                                                         #
echo  ###########################################################
echo.

if !FAIL! gtr 0 (exit /b 1) else (exit /b 0)

rem ============================================================
rem  子程序
rem ============================================================
:hashit
rem %1 = 文件路径（调用方已加引号），%2 = 接收哈希的变量名
set "%~2="
for /f "delims=" %%L in ('certutil -hashfile %1 SHA256 ^| findstr /r "^[0-9A-Fa-f][0-9A-Fa-f]*$"') do (
    if not defined %~2 set "%~2=%%L"
)
if defined %~2 (
    for /f "tokens=*" %%X in ("!%~2!") do set "%~2=%%X"
)
goto :EOF

:markfail
set /a FAIL+=1
set "FAIL_!FAIL!=%~1"
goto :EOF

:usage
echo 用法: install.bat [ecology根目录] [/verify]
echo.
echo   [ecology根目录]   ecology 安装根目录（含 classbean、mobile、WEB-INF 等子目录）
echo                     省略时按以下顺序解析:
echo                     1. 环境变量 ECOLOGY_ROOT
echo                     2. 默认 D:\WEAVER\ecology （会打印并暂停等待确认）
echo.
echo   /verify           仅校验模式：不复制、不备份，
echo                     只核对目标文件 SHA256 与 manifest.txt 是否一致。
echo.
echo 示例:
echo   install.bat D:\WEAVER\ecology
echo   install.bat D:\WEAVER\ecology /verify
echo   install.bat /verify
echo.
echo 退出码: 0 = 全部通过；1 = 存在失败或用法/环境错误。
exit /b 1
