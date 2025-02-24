# way-to-exe

electron中两种实现exe安装包的方式

在使用electron-build打包electron的window应用时，提供了nsis的方式，nsis是来着微软的比较经典的exe应用打包工具。electron-build工具内置了nsis的项目脚本，实现通过配置完成常见应用的打包，同时提供了用户自定义脚本的入口以满足个性化的需求。

方式1：使用nsis方式

```js
nsis: {
    oneClick: false,
    guid,
    perMachine: true,
    allowElevation: true,
    allowToChangeInstallationDirectory: true,
    createDesktopShortcut: true,
    createStartMenuShortcut: true,
    deleteAppDataOnUninstall: false, //卸载后删除用户数据
    shortcutName: productName,

    include: "installer.nsh", // 添加自定义脚本
    warningsAsErrors: false, // 忽略警告
},

```

预制脚本+自定义脚本


比如oneClick配置：源代码中的myInstallSection.nsh脚本配置如下

```js
!macro doStartApp
  # otherwise app window will be in background
  HideWindow
  !insertmacro StartApp
!macroend

!ifdef ONE_CLICK
  # https://github.com/electron-userland/electron-builder/pull/3093#issuecomment-403734568
  !ifdef RUN_AFTER_FINISH
    ${ifNot} ${Silent}
    ${orIf} ${isForceRun}
      !insertmacro doStartApp
    ${endIf}
  !else
    ${if} ${isForceRun}
      !insertmacro doStartApp
    ${endIf}
  !endif
  !insertmacro quitSuccess
!else
  # for assisted installer run only if silent, because assisted installer has run after finish option
  ${if} ${isForceRun}
  ${andIf} ${Silent}
    !insertmacro doStartApp
  ${endIf}
!endif

```
不满足业务需求的话，使用自定义脚本，插件灵活。

网站：https://nsis.sourceforge.io/Category:Plugins

比如要使用nsJSON对json文件进行修改，需要将nsJSON插件放到electron-build缓存中的nsis目录plugins下。
![alt text](images/nsis1.png)

![alt text](images/nsis2.png)

使用nsJSON自定义脚本

```js
# 修改db-config.json文件中数据库实例和端口号
nsJSON::Set /file "$INSTDIR\cpas-apps\db-config.json"
# 设置数据库实例值
nsJSON::Set `development` `testName` /value `"123456"`
# 设置数据库端口
nsJSON::Set `development` `testPort` /value `"7000"`
# 保存json文件
nsJSON::Serialize /format /file $INSTDIR\cpas-apps\db-config.json

```

如何自定义https://www.electron.build/nsis

除了插件，还暴露了几个钩子：

```js
!macro customHeader
  !system "echo '' > ${BUILD_RESOURCES_DIR}/customHeader"
!macroend

!macro preInit
  ; This macro is inserted at the beginning of the NSIS .OnInit callback
  !system "echo '' > ${BUILD_RESOURCES_DIR}/preInit"
!macroend

!macro customInit
  !system "echo '' > ${BUILD_RESOURCES_DIR}/customInit"
!macroend

!macro customInstall
  !system "echo '' > ${BUILD_RESOURCES_DIR}/customInstall"
!macroend

!macro customInstallMode
  # set $isForceMachineInstall or $isForceCurrentInstall
  # to enforce one or the other modes.
!macroend

!macro customWelcomePage
  # Welcome Page is not added by default for installer.
  !insertMacro MUI_PAGE_WELCOME
!macroend

!macro customUnWelcomePage
  !define MUI_WELCOMEPAGE_TITLE "custom title for uninstaller welcome page"
  !define MUI_WELCOMEPAGE_TEXT "custom text for uninstaller welcome page $\r$\n more"
  !insertmacro MUI_UNPAGE_WELCOME
!macroend

```
比如在使用时

```js

; 自定义删除文件
!macro customRemoveFiles
  ${if} ${isUpdated}
  ; 自动更新时不删除任何文件
  !insertmacro DetailPrintLog "自动更新时不删除任何文件......"
  ; 这是更新逻辑
  ; MessageBox MB_OK "isUpdated $INSTDIR 路径为: $INSTDIR"
  ${else}
  # Remove all files (or remaining shallow directories from the block above)
  RMDir /r $INSTDIR
  ${endif}
!macroend

```

结论：

1、需要非常熟悉这个脚本的语法编制，了解它的预制脚本的流程。尤其在删除操作是需要小心。
2、过程中生成的用户数据不能保留。如果要保留的话，更建议放在例如用户的AppData下。
3、它的自动更新是全量的，先删除后重新安装的过程。增量更新网上的更多方案是通过脚本替换resources包的方式。

整体流程：

```js
!define OUTDIR "$INSTDIR"
!define SQL_Path "C:\AudSQL2014"

!include LogicLib.nsh
!include x64.nsh

; 手动，写日志的函数
!macro DetailPrintLog text
  SetDetailsPrint both
  DetailPrint "Logging: ${text}" 
!macroend

; 方式1：(判断文件是否存储)检查 AudSQL2014 是否已安装
Function IsAudSQL2014Installed
  ; 设置安装路径
  StrCpy $0 "C:\AudSQL2014"

  ; 检查文件夹是否存在
  ${If} ${FileExists} "$0\*"
    ; 文件夹存在
    StrCpy $1 "1"
  ${Else}
    ; 文件夹不存在
    StrCpy $1 "0"
  ${EndIf}
FunctionEnd

; 方式2：(注册表判断)检查 AudSQL2014 是否已安装
; Function IsAudSQL2014Installed
;   # 64为系统
;   ${If} ${RunningX64}
;     ReadRegStr $0 HKLM "SOFTWARE\Microsoft\Microsoft SQL Server" "AudSQL2014"
;     StrCmp $0 "" 0 +2
;     # 如果注册表键不存在，则返回值为0
;     StrCpy $0 0
;     Goto Done
;     # 如果注册表键存在，则返回值为1
;     StrCpy $0 1
;   ${Else}
;     ReadRegStr $0 HKLM "SOFTWARE\WOW6432Node\Microsoft\Microsoft SQL Server" "AudSQL2014"
;     StrCmp $0 "" 0 +2
;     # 如果注册表键不存在，则返回值为0
;     StrCpy $0 0
;     Goto Done
;     # 如果注册表键存在，则返回值为1
;     StrCpy $0 1
;   ${EndIf}
;   Done:
;     # 返回结果
;     Push $0
; FunctionEnd

; 检查SQLServer实例是否安装的函数
Function GetSQLClientIsInstall
  ReadRegStr $0 HKLM "SOFTWARE\Classes\CLSID\{8F4A6B68-4F36-4e3c-BE81-BC7CA4E9C45C}" "ProgID"
  StrCmp $0 "" 0 +2
  # 如果注册表键不存在，则返回值为0
  StrCpy $0 0
  Goto Done
  # 如果注册表键存在，则返回值为1
  StrCpy $0 1
Done:
  # 返回结果
  Push $0
FunctionEnd

; 检查office版本的函数
Function DetectOfficeVersion
  ; 初始化为"未检测到Office"
  StrCpy $0 "Office not detected"

  ; 使用x64.nsh来判断系统是否为64位
  ${If} ${RunningX64}
    ; 系统为64位，检查Office 64位注册表项
    ReadRegStr $R0 HKLM "SOFTWARE\Microsoft\Office\ClickToRun\Configuration" "Platform"
    ${If} $R0 == "x64"
      StrCpy $0 "64-bit"
    ${ElseIf} $R0 == "x86"
      StrCpy $0 "32-bit"
    ${EndIf}

    ; 如果64位注册表项未找到，检查WOW6432Node中的32位Office注册表项
    ${If} $0 == "Office not detected"
      ReadRegStr $R0 HKLM "SOFTWARE\WOW6432Node\Microsoft\Office\ClickToRun\Configuration" "Platform"
      ${If} $R0 == "x64"
        StrCpy $0 "64-bit"
      ${ElseIf} $R0 == "x86"
        StrCpy $0 "32-bit"
      ${EndIf}
    ${EndIf}

  ${Else}
    ; 系统为32位，Office一定是32位
    StrCpy $0 "32-bit"
  ${EndIf}
FunctionEnd


!macro IsAudSQL2014Installed
  Call IsAudSQL2014Installed
  StrCpy $R1 $1
!macroend

!macro GetSQLClientIsInstall
  Call GetSQLClientIsInstall
  StrCpy $R0 $0
!macroend

!macro DetectOfficeVersion
  Call DetectOfficeVersion
  StrCpy $R0 $0
!macroend

; 安装sqlAudSQL2014数据库的函数
Function Install_AudSQL2014_Database
    ; 检查 AudSQL2014 是否已安装
    !insertmacro IsAudSQL2014Installed
    !insertmacro DetailPrintLog "insertmacro IsAudSQL2014Installed Result: $R1"
    ${If} $R1 == "0"
      ; 运行 AudSQL2014Express_Setup
      !insertmacro DetailPrintLog "安装AudSQL2014数据库"
      ExecWait '"$INSTDIR\Tools\AudSQL2014Express_Setup(AudSQL2014实例).exe" /sp- /silent /norestart'
      ; 判断是否为32位系统且SQL客户端未安装，安装SQL Server Native Client 32位
      !insertmacro GetSQLClientIsInstall
      !insertmacro DetailPrintLog "insertmacro GetSQLClientIsInstall Result: $R0"

      ${If} ${RunningX64}
        ${If} $R0 == "0"
          !insertmacro DetailPrintLog "正在安装AudSQL2014数据库客户端 - 64-bit"
          ExecWait '"msiexec" /i "$INSTDIR\Tools\SQLServerNativeClient64.msi" IACCEPTSQLNCLILICENSETERMS=YES /passive /log "$INSTDIR\Tools\SQLClient安装日志.log"'
        ${Else}
          !insertmacro DetailPrintLog "SQL Client already installed on 64-bit system"
        ${EndIf}
      ${Else}
        ${If} $R0 == "0"
          !insertmacro DetailPrintLog "正在安装AudSQL2014数据库客户端 - 32-bit"
          ExecWait '"msiexec" /i "$INSTDIR\Tools\SQLServerNativeClient32.msi" IACCEPTSQLNCLILICENSETERMS=YES /passive /log "$INSTDIR\Tools\SQLClient安装日志.log"'
        ${Else}
          !insertmacro DetailPrintLog "SQL Client already installed on 32-bit system"
        ${EndIf}
      ${EndIf}
      ; 启动数据库
      !insertmacro DetailPrintLog "正在启动数据库..."
      Exec '"net" start "AudSQL2014"'
    ${else}
      !insertmacro DetailPrintLog "AudSQL2014数据库已安装"
    ${endif}
    # 修改db-config.json文件中数据库实例和端口号
    # nsJSON::Set /file "$INSTDIR\cpas-apps\db-config.json"
    # 设置数据库实例值
    # nsJSON::Set `development` `testName` /value `"123456"`
    # 设置数据库端口
    # nsJSON::Set `development` `testPort` /value `"7000"`
    # 保存json文件
    # nsJSON::Serialize /format /file $INSTDIR\cpas-apps\db-config.json
    !insertmacro DetailPrintLog `更新db-config.json文件: $INSTDIR\cpas-apps\db-config.json`
FunctionEnd

; 安装Office加载项和工具的函数
Function Install_Office_Addins_Tools
  ; 检测Office版本
  !insertmacro DetectOfficeVersion
  !insertmacro DetailPrintLog "insertmacro DetectOfficeVersion Result: $R0"

  ${If} $R0 == "64-bit"
    !insertmacro DetailPrintLog "Running 64-bit Office setup..."
    ExecShell "" "$INSTDIR\UFCPAS4Office\64位Office请执行我.bat" "notpause" SW_HIDE
  ${ElseIf} $R0 == "32-bit"
    !insertmacro DetailPrintLog "Running 32-bit Office setup..."
    ExecShell "" "$INSTDIR\UFCPAS4Office\32位Office请执行我.bat" "notpause" SW_HIDE
  ${Else}
    !insertmacro DetailPrintLog "Office not detected, skipping Office add-ins installation."
  ${EndIf}

  !insertmacro DetailPrintLog "Registering Office add-ins..."
  ExecWait '"$INSTDIR\UFCPAS4Office\注册Office加载项6.exe" /sw' 

  ; cpas6.0 office加载项
  !insertmacro DetailPrintLog "cpas6.0 office加载项..."
  ExecWait '"$INSTDIR\Tools\vstor_redist.exe" /q /s'

  ; 正在安装UFCPAS6加载项
  !insertmacro DetailPrintLog "cpas6.0 office加载项add-in..."
  ExecWait '"msiexec" /i "$INSTDIR\Tools\cpas-report-office-addin.msi" IACCEPTSQLNCLILICENSETERMS=YES /quiet /passive /log "$INSTDIR\Tools\cpas-report-office-addin安装日志.log"'
FunctionEnd

; 初始化数据的函数
Function InitializeData
  !insertmacro DetailPrintLog "使用UFCPAS_Init.exe初始化数据"
  ; 执行UFCPAS_Init.exe并等待其完成
  ExecWait '"$INSTDIR\SourceData\UFCPAS_Init.exe" InstanceName=AudSql2014' $0

  ; 检查执行结果
  ${If} $0 == 0
    !insertmacro DetailPrintLog "Data initialization completed successfully."
  ${Else}
    MessageBox MB_OK|MB_ICONEXCLAMATION "Data initialization failed with error code $0."
  ${EndIf}
FunctionEnd

!macro Install_AudSQL2014_Database
  Call Install_AudSQL2014_Database
!macroend

!macro Install_Office_Addins_Tools
  Call Install_Office_Addins_Tools
!macroend

!macro InitializeData
  Call InitializeData
!macroend

!macro customHeader
  ShowInstDetails show
  ShowUninstDetails show
!macroend

!macro customInit
  ; 初始化日志文件
  ; FileDelete "$INSTDIR\install_log.txt"
  ${if} ${isUpdated}
    !insertmacro DetailPrintLog "更新程序......"
  ${else}
    ; 显示安装目录
    !insertmacro DetailPrintLog "安装目录: $INSTDIR"
    # 检测重复安装
    ; ReadRegStr $0 HKLM "SOFTWARE\Cpas-merge" "ShortcutName"
    ; ${If} $0 != ''
    ;   MessageBox MB_OK|MB_ICONSTOP "合并系统(注册表为Cpas-merge)已安装在计算机中。如需重新安装，请卸载已有的安装。"
    ;   Quit
    ; ${EndIf}
    ; 备份用户配置文件 
    !insertmacro DetailPrintLog "0 备份用户配置文件user-config"
 
    ; 组合条件判断：当且仅当 
    ; 1. user-config.json  存在 
    ; 2. user-config.json.bak  不存在 
    ${If} ${FileExists} "$INSTDIR\cpas-apps\user-config.json" 
    ${AndIfNot} ${FileExists} "$INSTDIR\cpas-apps\user-config.json.bak" 
        CopyFiles /SILENT "$INSTDIR\cpas-apps\user-config.json"  \
                  "$INSTDIR\cpas-apps\user-config.json.bak" 
        !insertmacro DetailPrintLog "Created backup: user-config.json.bak" 
    ${Else}
        !insertmacro DetailPrintLog "Backup skipped: $0"  ; $0存储具体原因 
    ${EndIf}
  ${endif}
  
!macroend

; 自定义安装
!macro customInstall
  !insertmacro DetailPrintLog "2"
  ${If} ${FileExists} "$INSTDIR\cpas-apps\user-config.json" 
    !insertmacro DetailPrintLog "安装包的文件已经生成了"
  ${EndIf}
  ; 恢复备份文件 
  ${If} ${FileExists} "$INSTDIR\cpas-apps\user-config.json.bak" 
    !insertmacro DetailPrintLog "恢复user-config文件"
    ; 执行重命名并捕获错误 
    ClearErrors 
    # 先删除
    Delete "$INSTDIR\cpas-apps\user-config.json"   ; 先删除旧文件 
    Rename "$INSTDIR\cpas-apps\user-config.json.bak"  "$INSTDIR\cpas-apps\user-config.json" 
      
    ${If} ${Errors}
        ; 阶段2：获取详细错误信息 
        System::Call "kernel32::GetLastError()i.r0"
        System::Call "kernel32::FormatMessageA(i 0x1000, p 0, i r0, i 0, t.r1, i 512, p 0)"
        !insertmacro DetailPrintLog "标准重命名失败 (代码: $0 / 描述: $1)"
          
        ; 尝试强制替换 
        System::Call 'kernel32::MoveFileExA( \
            t "$INSTDIR\cpas-apps\user-config.json.bak",  \
            t "$INSTDIR\cpas-apps\user-config.json",  \
            i 0x00000004)i.r0'  ; MOVEFILE_REPLACE_EXISTING 
        ${If} $2 != 0 
            !insertmacro DetailPrintLog "强制替换成功"
        ${Else}
            System::Call "kernel32::GetLastError()i.r3"
            !insertmacro DetailPrintLog "强制替换失败 (代码: $3)"
        ${EndIf}
    ${Else}
        !insertmacro DetailPrintLog "标准重命名成功"
    ${EndIf}
  ${EndIf}
  # 打印信息出来
  !insertmacro DetailPrintLog "自定义安装开始......"
  ; 自动更新阶段
  ${if} ${isUpdated}
    !insertmacro DetailPrintLog "更新程序..."
  ${else}
    ; 调用sqlAudSQL2014数据库的函数
    !insertmacro Install_AudSQL2014_Database

    ; Office 加载项和工具安装
    !insertmacro Install_Office_Addins_Tools

    ; 调用数据初始化函数
    !insertmacro InitializeData
  ${endif}
  
  !insertmacro DetailPrintLog "自定义安装结束......"
!macroend

; 自定义卸载
!macro customUnInstall
    ${if} ${isUpdated}
        ; 这是更新逻辑
        ; MessageBox MB_OK "isUpdated 条件为真，PLUGINSDIR 路径为: $PLUGINSDIR"
    ${else}
        ; 这是新安装逻辑
        ; MessageBox MB_OK "This is a fresh installation." /SD IDOK IDOK label_ok
      ; label_ok:
        ; MessageBox MB_OK "你点击了OK"
    ${endif}
!macroend

!macro GetRelativePathMacro INSTALL_DIR FULL_PATH OUTPUT_VAR 
    ; 参数说明：
    ; INSTALL_DIR - 安装根目录（示例："$INSTDIR"）
    ; FULL_PATH   - 完整文件路径（示例："$INSTDIR\data\config.ini" ）
    ; OUTPUT_VAR  - 输出变量（示例：$R3）
 
    Push $0  ; 保护寄存器 
    Push $1 
    Push $2 
    
    ; 校验路径前缀 
    StrLen $0 "${INSTALL_DIR}"
    StrCpy $1 "${FULL_PATH}" "" $0  ; 截取尾部 
    
    ; 处理首字符反斜杠 
    StrCpy $2 $1 1  ; 取第一个字符 
    ${If} $2 == "\"
        StrCpy $1 $1 "" 1  ; 去除首字符 
    ${EndIf}
    
    StrCpy ${OUTPUT_VAR} $1 
    
    Pop $2  ; 恢复寄存器 
    Pop $1 
    Pop $0 
!macroend 
; 保留特定目录
!macro KeepDirs install_path 
  ; 定义保留目录 
    StrCpy $R0 "cpas-apps"     ; 核心配置目录 
    StrCpy $R1 "resources"     ; 资源目录 
    StrCpy $R2 "logs"          ; 日志目录 

    FindFirst $0 $1 "${install_path}\*"

    loop:
        StrCmp $1 "" done  ; 遍历结束 
        StrCmp $1 "."  skip ; 跳过当前目录 
        StrCmp $1 ".." skip  ; 跳过上级目录 
        ;-----------------------------
        ; 目录保留判断（扩展为3个目录）
        ;-----------------------------
        ${If} $1 == $R0 
        ${OrIf} $1 == $R1 
        ${OrIf} $1 == $R2      ; 新增条件 
            !insertmacro DetailPrintLog "[保留目录] $1"
            Goto skip_delete 
        ${EndIf}

        ;-----------------------------
        ; 文件保留判断
        ;-----------------------------
        ${IfNot} ${FileExists} "$INSTDIR\$1\*.*"
            StrCpy $2 "$INSTDIR\$1"
            !insertmacro GetRelativePathMacro "$INSTDIR" "$2" $3 
            !insertmacro DetailPrintLog "[相对路径] $3"
            ${If} $3 == "cpas-apps\user-config.json"  
                !insertmacro DetailPrintLog "[保留user-config] $3"
                Goto skip_delete 
            ${EndIf}
        ${EndIf}

        ${If} ${FileExists} "${install_path}\$1\*.*" ; 目录处理 
            RMDir /r "${install_path}\$1"
            !insertmacro DetailPrintLog "删除目录: $1"
        ${Else}
            Delete "${install_path}\$1"
            !insertmacro DetailPrintLog "删除文件: $1"
        ${EndIf}
        goto next
        
        skip_delete:
            !insertmacro DetailPrintLog "保留目录：$1"
        skip:
        next:
            FindNext $0 $1 
            goto loop 
    done:
    FindClose $0 
!macroend 
 
; 自定义删除文件
!macro customRemoveFiles 
    ; 备份用户配置文件 
    !insertmacro DetailPrintLog "0 备份用户配置文件user-config"
    ${If} ${FileExists} "$INSTDIR\cpas-apps\user-config.json" 
    ${AndIfNot} ${FileExists} "$INSTDIR\cpas-apps\user-config.json.bak" 
        CopyFiles /SILENT "$INSTDIR\cpas-apps\user-config.json"  \
                  "$INSTDIR\cpas-apps\user-config.json.bak" 
        !insertmacro DetailPrintLog "Created backup: user-config.json.bak" 
    ${Else}
        !insertmacro DetailPrintLog "Backup skipped: $0"  ; $0存储具体原因 
    ${EndIf}

    ${if} ${isUpdated}
      !insertmacro DetailPrintLog "更新模式：跳过文件清理"
    ${endif}
    !insertmacro DetailPrintLog "1"
    ; 自定义保留目录
    # !insertmacro KeepDirs "$INSTDIR"
!macroend 
```

方式2：使用InnoSetup方式

生成环境成熟方案：

1、保留用户生成的数据
2、增量和全量更新机制

报告系统的iss脚本大概流程：

![alt text](images/流程.png)

支持独立的合并系统安装包：

1、本地数据库的适配（客户数据库不一致，需要单独部署）；
    a)独立的实例
    b)安装时在Config.ini或db-config.json中初始化写入数据库信息。
2、继续保持云端的ORCLE数据库支持；（不用变）
3、projectData等文件目录从报告系统脱离
    a)平台端代码层，appPath基础目录的修改
4、打包方式走Innosetup的方式
    a)iss脚本的编写
5、office加载项是否需要支持独立的版本 
    a)UFCPAS4Office
    b)vstor_redist
    c)cpas-report-office-addin.msi
基于1和5的实现
6、5设计的时候能否，支持安装2个包呢。比如合并系统测试版和正式版。比如谷歌浏览器可以安装正式版和开发版dev，dev版体验新的功能。
