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

echo 正在生成 VMD 渲染脚本...

echo 正在生成 VMD 渲染脚本...

:: 5. 生成 Tcl 脚本
(
    echo proc orb {iorb} {
    echo     #Set the isovalue for showing orbitals here. 0.02~0.06 is commonly used.
    echo     set isoval 0.05
    echo     #Set the material for showing orbitals here. Glossy and EdgyGlass are recommended.
    echo     set mater Glossy
    echo     light 3 on
    echo     color Display Background white
    echo     display depthcue off
    echo     # 注意: 如果继续闪退，请在下一行前面加上 # 注释掉 GLSL
    echo     display rendermode GLSL
    echo     axes location Off
    echo.
    echo     # 保存当前视角
    echo     if {[molinfo num]^>0} {
    echo         set viewpoint [molinfo top get {center_matrix rotate_matrix scale_matrix}]
    echo     }
    echo     # 删除旧分子并加载新轨道
    echo     mol delete top
    echo     mol new $iorb
    echo.
    echo     mol modstyle 0 top CPK 0.800000 0.300000 22.000000 22.000000
	echo		 mol modmaterial 0 top Diffuse	
    echo     mol addrep top
    echo     mol modstyle 1 top Isosurface $isoval 0 0 0 1 1
    echo     mol modcolor 1 top ColorID 1
    echo     mol modmaterial 1 top $mater
    echo     mol addrep top
    echo     mol modstyle 2 top Isosurface -$isoval 0 0 0 1 1
    echo     mol modcolor 2 top ColorID 0
    echo     mol modmaterial 2 top $mater
    echo.
    echo     # 恢复之前保存的视角
    echo     if [info exists viewpoint] {
    echo         molinfo top set {center_matrix rotate_matrix scale_matrix} $viewpoint
    echo     }
    echo }
    echo.
    echo proc renderx {} {
    echo     color Name C tan
    echo     color change rgb tan 0.700000 0.560000 0.360000
    echo     material change mirror Opaque 0.15
    echo     material change outline Opaque 4.000000
    echo     material change outlinewidth Opaque 0.5
    echo     material change ambient Glossy 0.1
    echo     material change diffuse Glossy 0.600000
    echo     material change opacity Glossy 0.75
    echo     material change shininess Glossy 1.0
    echo     mol modcolor 1 top ColorID 12
    echo     mol modcolor 2 top ColorID 22
    echo     display distance -7.0
    echo     display height 10
    echo     light 3 on
    echo }
    echo.
    echo proc orbiso {isoval} {
    echo     mol modstyle 1 top Isosurface $isoval 0 0 0 1 1
    echo     mol modstyle 2 top Isosurface -$isoval 0 0 0 1 1
    echo }
    echo.
    echo proc orbclean {} {
    echo     # 增加了 -nocomplain 防止没有匹配文件时 Tcl 报错
    echo     file delete {*}[glob -nocomplain orb*.cub]
    echo }
    echo.
    echo # 自动执行命令，传入批处理解析好的文件路径
    echo orb "!CUB_FILE!"
    echo renderx
    echo menu main on 
) > "!TEMP_TCL!"

:: 6. 运行 VMD (只传脚本参数即可，文件在脚本内加载)
echo 正在启动 VMD...
"!VMD_PATH!" -e "!TEMP_TCL!"

:: 清理环境
endlocal