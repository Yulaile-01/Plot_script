@echo off
:: 强制将 CMD 窗口编码切换为 UTF-8，解决中文乱码问题
chcp 65001 >nul

:: 开启延迟变量扩展，用于处理路径中的字符串替换
setlocal enabledelayedexpansion

:: 1. 检查是否拖放了文件
if "%~1"=="" (
    echo [错误] 请将 .cub 文件拖放到此脚本上！
    pause
    exit /b
)

:: 2. 检查文件扩展名是否是 .cub
if /i not "%~x1"==".cub" (
    echo [错误] 请拖放 .cub 格式的文件！当前拖放的文件为: "%~nx1"
    pause
    exit /b
)

echo 拖拽的文件路径："%~1"
cd /d "%~dp1"

:: 3. 设置 VMD 路径（请确保此路径正确）
set "VMD_ROOT=C:\Program Files (x86)\University of Illinois\VMD"
set "VMD_PATH=%VMD_ROOT%\vmd.exe"

:: 检查 VMD 是否存在，防止路径错误导致的闪退
if not exist "!VMD_PATH!" (
    echo [错误] 找不到 VMD 可执行文件！
    echo 请检查脚本中的 VMD_ROOT 路径是否正确："!VMD_ROOT!"
    pause
    exit /b
)

:: 4. 路径处理：将 Windows 的反斜杠 \ 替换为 Tcl 能识别的正斜杠 /
set "CUB_FILE=%~1"
set "CUB_FILE=!CUB_FILE:\=/!"

:: 将临时 tcl 脚本生成在当前目录，避免 %TEMP% 路径可能包含中文的风险
set "TEMP_TCL=%~dp1vmd_auto_temp.tcl"
set "TEMP_TCL_FWD=!TEMP_TCL:\=/!"


echo 正在生成 VMD Tcl 脚本到 "%TEMP_TCL%"...
(
    echo mol new sl2r.cub
    echo mol addfile dg_inter.cub
    echo mol delrep 0 top
    echo mol representation CPK 1.0 0.3 18.0 16.0
    echo mol addrep top
    echo mol representation Isosurface 0.00500 1 0 0 1 1
    echo mol color Volume 0
    echo mol addrep top
    echo mol scaleminmax top 1 -0.05 0.05
    echo color scale method BGR
    echo color Display Background white
    echo axes location Off
    echo display depthcue off
    echo display rendermode GLSL
    echo light 3 on
    echo material change specular Opaque 0.300000
    echo # 可选：如果要让 VMD 在脚本执行后自动关闭，请取消注释下一行
    echo # quit
) > "%TEMP_TCL%"

:: --- 执行 VMD ---
echo 正在启动 VMD 并运行脚本...
start "" "%VMD_PATH%" -e "%TEMP_TCL%" 

:: 清理临时 Tcl 脚本（如果需要，请取消注释）
:: del "%TEMP_TCL%"

echo VMD 已成功启动。

endlocal
exit /b 0