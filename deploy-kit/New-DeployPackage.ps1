<#
.SYNOPSIS
    泛微 ecology 二开部署打包工具（PowerShell 5.1 兼容）。

.DESCRIPTION
    按显式清单文件从源根目录打包，生成可直接拷贝到服务器的 zip。
    zip 内布局：
        install.bat          服务器端安装脚本（纯批处理）
        README.txt           中文使用说明
        manifest.txt         清单+校验和，每行 "包内相对路径|SHA256大写十六进制"
        files\               目标布局（ecology 安装根下的相对路径）

    安全约定：绝不通配符自动抓文件，只打包清单中列出的文件，
    防止误打入 wecom.properties 等敏感文件。

.PARAMETER SourceRoot
    源文件根目录，例如 D:\DemoRepo\out\production\OrderModule

.PARAMETER MapFile
    清单文件，每行 "源文件相对路径 => 压缩包内路径"（制表符或 => 分隔）。
    "=>" 左侧相对 SourceRoot，右侧为 zip 内 files\ 下的相对路径（即 ecology 根下的相对路径）。
    以 # 开头的行与空行被忽略。

.PARAMETER Name
    包名，用于 zip 文件名，如 order-ledger-deploy

.PARAMETER OutDir
    zip 输出目录，不存在则创建。省略时默认 = 本工具包上一级的 deploy\（项目预先指定的
    输出目录）；演练，或项目档案登记了其他输出目录时，才显式指定其他目录。

.EXAMPLE
    .\New-DeployPackage.ps1 -SourceRoot D:\DemoRepo\out\production\OrderModule `
        -MapFile .\maps\order-ledger-increment-sample.map -Name order-ledger-deploy
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)] [string]$SourceRoot,
    [Parameter(Mandatory = $true)] [string]$MapFile,
    [Parameter(Mandatory = $true)] [string]$Name,
    [string]$OutDir
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version 2.0

# ---------- 基础校验 ----------
if (-not (Test-Path -LiteralPath $MapFile)) {
    Write-Host "[错误] 清单文件不存在: $MapFile" -ForegroundColor Red
    exit 1
}
if (-not (Test-Path -LiteralPath $SourceRoot -PathType Container)) {
    Write-Host "[错误] 源根目录不存在: $SourceRoot" -ForegroundColor Red
    exit 1
}

$sourceRootFull = (Resolve-Path -LiteralPath $SourceRoot).Path
$scriptRoot = $PSScriptRoot
if ([string]::IsNullOrWhiteSpace($scriptRoot)) { $scriptRoot = (Get-Location).Path }

# 输出目录：省略时默认 = 工具包上一级的 deploy\（项目预先指定的输出目录）；
# 仅演练等例外场景才显式传 -OutDir（传了非默认值时给出确认提示）。
$defaultOutDir = Join-Path (Split-Path -Parent $scriptRoot) 'deploy'
if ([string]::IsNullOrWhiteSpace($OutDir)) {
    $OutDir = $defaultOutDir
}
elseif (-not ($OutDir.TrimEnd('\') -ieq $defaultOutDir.TrimEnd('\'))) {
    Write-Host ("[提示] 输出目录非项目默认输出目录（{0}）：请确认这是项目档案指定的输出目录或演练目录。" -f $defaultOutDir) -ForegroundColor Yellow
}

$installBat = Join-Path $scriptRoot 'install.bat'
$readmeTxt  = Join-Path $scriptRoot 'README.txt'
foreach ($f in @($installBat, $readmeTxt)) {
    if (-not (Test-Path -LiteralPath $f)) {
        Write-Host "[错误] 缺少随包文件（应与本脚本同目录）: $f" -ForegroundColor Red
        exit 1
    }
}

# ---------- 解析清单 ----------
function Split-MapLine {
    param([string]$Line)
    $s = $Line.Trim()
    if ($s -eq '' -or $s.StartsWith('#')) { return $null }
    $sepIdx = $s.IndexOf('=>')
    if ($sepIdx -ge 0) {
        $src = $s.Substring(0, $sepIdx).Trim()
        $dst = $s.Substring($sepIdx + 2).Trim()
    }
    else {
        # 制表符分隔：取第一个制表符
        $tabIdx = $s.IndexOf("`t")
        if ($tabIdx -lt 0) {
            throw [System.FormatException]("清单行格式错误（既无 => 也无制表符）: $Line")
        }
        $src = $s.Substring(0, $tabIdx).Trim()
        $dst = $s.Substring($tabIdx + 1).Trim()
    }
    if ($src -eq '' -or $dst -eq '') {
        throw [System.FormatException]("清单行源路径或目标路径为空: $Line")
    }
    return @{ Source = $src; Target = $dst }
}

$entries = New-Object System.Collections.ArrayList
$lineNo = 0
foreach ($line in [System.IO.File]::ReadAllLines($MapFile)) {
    $lineNo++
    $parsed = Split-MapLine -Line $line
    if ($null -eq $parsed) { continue }
    $srcRel = $parsed.Source
    $dstRel = $parsed.Target.Replace('\', '/')

    # 目标路径安全校验：必须相对、无 ..
    if ([System.IO.Path]::IsPathRooted($dstRel) -or $dstRel -match '\.\.') {
        Write-Host "[错误] 第 $lineNo 行目标路径非法（必须为相对路径且不含 ..）: $dstRel" -ForegroundColor Red
        exit 1
    }
    if ($dstRel -match '^(install\.bat|README\.txt|manifest\.txt)$') {
        Write-Host "[错误] 第 $lineNo 行目标路径与随包文件冲突: $dstRel" -ForegroundColor Red
        exit 1
    }

    $srcFull = Join-Path $sourceRootFull ($srcRel.Replace('/', '\'))
    if (-not (Test-Path -LiteralPath $srcFull -PathType Leaf)) {
        Write-Host "[错误] 第 $lineNo 行源文件不存在: $srcFull" -ForegroundColor Red
        exit 1
    }
    # 确认源文件确实在源根内（防 ../../../ 越界）
    $srcResolved = (Resolve-Path -LiteralPath $srcFull).Path
    if (-not $srcResolved.StartsWith($sourceRootFull.TrimEnd('\') + [string][char]92, [System.StringComparison]::OrdinalIgnoreCase)) {
        Write-Host "[错误] 第 $lineNo 行源文件越出源根目录: $srcResolved" -ForegroundColor Red
        exit 1
    }

    # 目标路径去重
    foreach ($e in $entries) {
        if ($e.Target -ieq $dstRel) {
            Write-Host "[错误] 第 $lineNo 行目标路径重复: $dstRel" -ForegroundColor Red
            exit 1
        }
    }

    [void]$entries.Add(@{ Source = $srcResolved; Target = $dstRel })
}

if ($entries.Count -eq 0) {
    Write-Host "[错误] 清单为空，未解析到任何文件。" -ForegroundColor Red
    exit 1
}

# ---------- 暂存目录 ----------
if (-not (Test-Path -LiteralPath $OutDir)) {
    New-Item -ItemType Directory -Path $OutDir -Force | Out-Null
}
$outDirFull = (Resolve-Path -LiteralPath $OutDir).Path

$stamp  = Get-Date -Format 'yyyyMMdd-HHmmss'
$stage  = Join-Path $outDirFull ('.stage-{0}-{1}' -f $Name, $stamp)
$filesRoot = Join-Path $stage 'files'
New-Item -ItemType Directory -Path $filesRoot -Force | Out-Null

try {
    # ---------- 拷贝 payload 并计算哈希 ----------
    $manifestLines = New-Object System.Collections.ArrayList
    $copied = 0
    foreach ($e in $entries) {
        $dstFull = Join-Path $filesRoot ($e.Target.Replace('/', '\'))
        $dstDir = Split-Path -Parent $dstFull
        if (-not (Test-Path -LiteralPath $dstDir)) {
            New-Item -ItemType Directory -Path $dstDir -Force | Out-Null
        }
        Copy-Item -LiteralPath $e.Source -Destination $dstFull -Force

        $hash = (Get-FileHash -LiteralPath $dstFull -Algorithm SHA256).Hash.ToUpperInvariant()
        [void]$manifestLines.Add(('{0}|{1}' -f $e.Target, $hash))
        $copied++
    }

    # ---------- 生成 manifest.txt（UTF-8 无 BOM，正斜杠，LF 行尾） ----------
    $manifestPath = Join-Path $stage 'manifest.txt'
    $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    $manifestText = (($manifestLines -join "`n") + "`n")
    [System.IO.File]::WriteAllText($manifestPath, $manifestText, $utf8NoBom)

    # ---------- 放入随包文件 ----------
    # install.bat 必须是 CRLF 行尾（cmd.exe 不认 LF）。此处按字节处理
    # （Latin-1 与字节一一对应，无损），避免 Encoding.Default 与实际
    # 文件编码（GBK）不一致时把中文冲掉。
    $batBytes = [System.IO.File]::ReadAllBytes($installBat)
    $latin1   = [System.Text.Encoding]::GetEncoding(28591)
    $batText  = $latin1.GetString($batBytes)
    $batText  = $batText -replace "`r`n", "`n"
    $batText  = $batText -replace "`n", "`r`n"
    [System.IO.File]::WriteAllBytes((Join-Path $stage 'install.bat'), $latin1.GetBytes($batText))
    Copy-Item -LiteralPath $readmeTxt -Destination (Join-Path $stage 'README.txt') -Force

    # ---------- 打 zip（ZipFile.CreateFromDirectory 保留目录结构） ----------
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $zipPath = Join-Path $outDirFull ('{0}-{1}.zip' -f $Name, $stamp)
    if (Test-Path -LiteralPath $zipPath) { Remove-Item -LiteralPath $zipPath -Force }
    [System.IO.Compression.ZipFile]::CreateFromDirectory($stage, $zipPath)

    $zipItem = Get-Item -LiteralPath $zipPath
    Write-Host ''
    Write-Host '[完成] 打包成功' -ForegroundColor Green
    Write-Host ("  zip      : {0}" -f $zipPath)
    Write-Host ("  文件数   : {0}（另有 install.bat / README.txt / manifest.txt）" -f $copied)
    Write-Host ("  zip 大小 : {0:N1} KB" -f ($zipItem.Length / 1KB))
    Write-Host ("  清单     : {0}" -f $manifestPath)
    Write-Host ''
    Write-Host '下一步：将 zip 拷贝到 ecology 服务器，解压后运行 install.bat，完成后务必重启 ecology 服务。' -ForegroundColor Yellow
    exit 0
}
catch {
    Write-Host ('[错误] 打包失败: {0}' -f $_.Exception.Message) -ForegroundColor Red
    exit 1
}
finally {
    if (Test-Path -LiteralPath $stage) {
        Remove-Item -LiteralPath $stage -Recurse -Force -ErrorAction SilentlyContinue
    }
}
