!define OUTDIR "$INSTDIR"
!define SQL_Path "C:\AudSQL2014"
!define SQL_ServerName "(local)\AudSQL2014"

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
    nsJSON::Set /file "$INSTDIR\cpas-apps\db-config.json"
    # 设置数据库实例值
    nsJSON::Set `development` `testName` /value `"123456"`
    # 设置数据库端口
    nsJSON::Set `development` `testPort` /value `"7000"`
    # 保存json文件
    nsJSON::Serialize /format /file $INSTDIR\cpas-apps\db-config.json
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
  ${endif}
!macroend

; 自定义安装
!macro customInstall
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



