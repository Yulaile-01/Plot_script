@echo off
:: 切换为 UTF-8，防止中文乱码
chcp 65001 >nul

:: 开启延迟变量扩展
setlocal enabledelayedexpansion

echo ========================================
echo        VMD 脚本自动生成器 (拖拽模式)
echo ========================================

:: 1. 获取文件路径 (仅支持拖放)
if "%~1"=="" (
    echo [错误] 未检测到文件！
    echo [提示] 请将你的 .cub 文件直接拖放到这个 bat 脚本图标上运行。
    pause
    exit /b
)

set "USER_INPUT_PATH=%~1"

:: 去除引号并提取路径元素
set "USER_INPUT_PATH=!USER_INPUT_PATH:"=!"

if not exist "!USER_INPUT_PATH!" (
    echo [错误] 找不到该文件: "!USER_INPUT_PATH!"
    pause
    exit /b
)

for %%A in ("!USER_INPUT_PATH!") do (
    set "FILE_EXT=%%~xA"
    set "FILE_DIR=%%~dpA"
    set "FILE_NAME=%%~nxA"
)

if /i not "!FILE_EXT!"==".cub" (
    echo [错误] 请提供 .cub 格式文件！当前拖入的是: "!FILE_NAME!"
    pause
    exit /b
)

echo [调试] 目标文件："!USER_INPUT_PATH!"
cd /d "!FILE_DIR!"
echo [调试] 工作目录已切换至：!CD!

:: 3. 检查 VMD 路径
set "VMD_ROOT=C:\Program Files (x86)\University of Illinois\VMD"
set "VMD_PATH=%VMD_ROOT%\vmd.exe"

if not exist "!VMD_PATH!" (
    echo [错误] 找不到 VMD！路径: "!VMD_PATH!"
    pause
    exit /b
)

set "CUB_FILE=!USER_INPUT_PATH!"
set "CUB_FILE=!CUB_FILE:\=/!"
set "TEMP_TCL=!FILE_DIR!vmd_auto_temp.tcl"
set "LOG_FILE=!FILE_DIR!vmd_debug.log"

:: 解除文件占用：尝试删除旧日志
if exist "!LOG_FILE!" (
    del /q /f "!LOG_FILE!" >nul 2>&1
    if exist "!LOG_FILE!" (
        echo [警告] 无法删除旧的 vmd_debug.log，可能正被记事本打开！
        echo [警告] 请关闭该日志文件后再试，或者忽略此警告继续。
    )
)

:: 提取 PDB 坐标
set "PDB_FILE=surfanalysis.pdb"
echo [处理] 正在提取 %PDB_FILE% 数据并生成 CCC.txt / OOO.txt ...

:: Python 行命令执行 (强化文件句柄释放)
python -c "import sys; c=[]; o=[]; lines=open('!PDB_FILE!','r').readlines(); [c.append(l[6:11].strip()+' '+l[12:16].strip()+' '+l[30:38].strip()+' '+l[38:46].strip()+' '+l[46:54].strip()+' '+l[60:66].strip()+'\n') if l[12:16].strip().startswith('C') else (o.append(l[6:11].strip()+' '+l[12:16].strip()+' '+l[30:38].strip()+' '+l[38:46].strip()+' '+l[46:54].strip()+' '+l[60:66].strip()+'\n') if l[12:16].strip().startswith('O') else None) for l in lines if l.startswith(('ATOM','HETATM'))]; open('CCC.txt','w').writelines(c); open('OOO.txt','w').writelines(o);"

if %ERRORLEVEL% EQU 0 (
    echo [成功] CCC.txt 和 OOO.txt 生成完毕。
) else (
    echo [错误] 数据提取失败！请检查 Python 是否正确安装或 PDB 文件是否存在。
    pause
    exit /b
)

echo [调试] 正在生成 VMD 渲染脚本到 "!TEMP_TCL!"...

:: 5. 生成 Tcl 脚本 
(
    echo # ==========================================
    echo # 1. 全局显示与材质设置
    echo # ==========================================
    echo color scale method BWR
    echo color Display Background white
    echo axes location Off
    echo display depthcue off
    echo display rendermode GLSL
    echo light 2 on
    echo light 3 on
    echo.
    echo # 设置 EdgyGlass 材质参数
    echo material change transmode EdgyGlass 1.0
    echo material change specular EdgyGlass 0.15
    echo material change shininess EdgyGlass 0.95
    echo material change opacity EdgyGlass 0.7
    echo material change outlinewidth EdgyGlass 0.9
    echo material change outline EdgyGlass 0.5
    echo.
    echo # ==========================================
    echo # 2. 加载静电势 ^(ESP^) Cub 文件
    echo # ==========================================
    echo set nsystem 1
    echo for {set i 1} {$i ^<= $nsystem} {incr i} {
    echo     set id [expr {$i - 1}]
    echo.    
    echo     mol new density.cub
    echo     mol addfile totesp.cub
    echo.    
    echo     mol modstyle 0 $id CPK 1.000000 0.300000 22.000000 22.000000
    echo     mol addrep $id
    echo.    
    echo     mol modstyle 1 $id Isosurface 0.001000 0 0 0 1 1
    echo     mol modmaterial 1 $id EdgyGlass
    echo     mol modcolor 1 $id Volume 1
    echo.
    echo     mol scaleminmax $id 1 -0.03 0.03
    echo.
    echo }
    echo.
    echo # ==========================================
    echo # 3. 加载表面分析 PDB 文件
    echo # ==========================================
    echo mol new surfanalysis.pdb
    echo set pdb_id [molinfo top] 
    echo.
    echo mol modstyle 0 $pdb_id VDW 0.07 20
    echo mol modselect 0 $pdb_id name C
    echo mol modcolor 0 $pdb_id ColorID 32
    echo mol addrep $pdb_id
    echo.
    echo mol modstyle 1 $pdb_id VDW 0.07 20
    echo mol modselect 1 $pdb_id name O
    echo mol modcolor 1 $pdb_id ColorID 21
    echo.
    echo # 计算中心坐标 ^(注意清理 atomselect 以防内存泄露^)
    echo set sel_all [atomselect $pdb_id all]
    echo set center_xyz [measure center $sel_all]
    echo $sel_all delete
    echo.
    echo # ==========================================
    echo # 4. 绘图相关函数定义
    echo # ==========================================
    echo proc ret { x y z expr_len val } {
    echo     global center_xyz
    echo     set xi [lindex $center_xyz 0]
    echo     set yi [lindex $center_xyz 1]
    echo     set zi [lindex $center_xyz 2]
    echo     set xx [expr {$x - $xi}]
    echo     set yy [expr {$y - $yi}]
    echo     set zz [expr {$z - $zi}]
    echo     set dis [expr {sqrt^($xx*$xx + $yy*$yy + $zz*$zz^)}]
    echo     if {$dis == 0} { set dis 0.0001 }
    echo     set mul [expr {^($dis + $expr_len^) / $dis}]
    echo     set xp [expr {$xx * $mul}]
    echo     set yp [expr {$yy * $mul}]
    echo     set zp [expr {$zz * $mul}]
    echo     set rx [expr {$xi + $xp}]
    echo     set ry [expr {$yi + $yp}]
    echo     set rz [expr {$zi + $zp}]
    echo     draw color black
    echo     draw line "$x $y $z" "$rx $ry $rz" width 3 style dashed
    echo     if { $val ^< 0 } { 
    echo         draw color blue 
    echo     } else { 
    echo         draw color red 
    echo     }
    echo     draw text "$rx $ry $rz" $val
    echo }
    echo.
    echo proc draw_esp_line { count_esp count_dis } {
    echo     global pdb_id
    echo     draw delete all 
    echo     set gol_c {}
    echo     set gol_o {} 
    echo.    
    echo     if {[file exists "CCC.txt"]} {
    echo         set indc $count_esp
    echo         set fp [open "CCC.txt" r]
    echo         while { [gets $fp data] ^>= 0 ^&^& $indc ^> 0 } {
    echo             incr indc -1
    echo             set serial [lindex $data 0]
    echo             set px [lindex $data 2]
    echo             set py [lindex $data 3]
    echo             set pz [lindex $data 4]
    echo             set val [lindex $data 5]
    echo             set len 3
    echo             ret $px $py $pz $count_dis $val
    echo             lappend gol_c $serial
    echo         }
    echo         close $fp 
    echo     } else {
    echo         puts "警告: 未找到 CCC.txt"
    echo     }
    echo.    
    echo     if {[file exists "OOO.txt"]} {
    echo         set indo $count_esp
    echo         set fp [open "OOO.txt" r]
    echo         while { [gets $fp data] ^>= 0 ^&^& $indo ^> 0 } {
    echo             incr indo -1
    echo             set serial [lindex $data 0]
    echo             set px [lindex $data 2]
    echo             set py [lindex $data 3]
    echo             set pz [lindex $data 4]
    echo             set val [lindex $data 5]
    echo             ret $px $py $pz $count_dis $val
    echo             lappend gol_o $serial
    echo         }
    echo         close $fp 
    echo     } else {
    echo         puts "警告: 未找到 OOO.txt"
    echo     }
    echo.    
    echo     set ccc "serial [join $gol_c " "]"
    echo     set ooo "serial [join $gol_o " "]"
    echo.    
    echo     if {[llength $gol_c] ^> 0} {
    echo         mol modselect 0 $pdb_id $ccc
    echo     } else {
    echo         mol modselect 0 $pdb_id "none"
    echo     }
    echo.    
    echo     if {[llength $gol_o] ^> 0} {
    echo         mol modselect 1 $pdb_id $ooo
    echo     } else {
    echo         mol modselect 1 $pdb_id "none"
    echo     }
    echo }
    echo.
    echo draw_esp_line 3 3
) > "!TEMP_TCL!"

echo [调试] Tcl 脚本已成功生成！
echo ========================================
echo 准备启动 VMD，如遇闪退请查看日志记录。

:: 启动 VMD 
echo 正在运行 VMD，请稍候... 
"!VMD_PATH!" -e "!TEMP_TCL!"

echo ========================================
echo [完成] VMD 运行结束！日志文件已保存。
pause
endlocal
exit /b 0