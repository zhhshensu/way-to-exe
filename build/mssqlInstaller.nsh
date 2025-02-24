!include LogicLib.nsh 
!include FileFunc.nsh 
!include "nsDialogs.nsh" 
!include "WinCore.nsh" 

Function FindAvailablePort
    System::Call "iphlpapi::GetTcpTable(p.r0, *i ${NSIS_MAX_STRLEN}, i 0)i.r1"
    ${If} $1 == 0
        IntOp $2 0 + 0
        ${Do}
            System::Call "*$0(i.r3, i.r4, i.r5, i.r6, i.r7)" $2
            ${If} $5 == 1433  ; 检测默认端口
                StrCpy $8 1  ; 标记占用
                ${ExitDo}
            ${EndIf}
            IntOp $2 $2 + 1
        ${LoopUntil} $2 >= $1
    ${EndIf}
    ${If} $8 == 1
        ; 动态分配策略
        StrCpy $Port 1433
        ${Do}
            IntOp $Port $Port + 1
            System::Call "kernel32::CreateFile(t '\\.\COM$Port', i 0x80000000, i 0, p 0, i 3, i 0, i 0)i.r0"
            ${If} $0 != -1
                System::Call "kernel32::CloseHandle(p $0)"
            ${Else}
                ${ExitDo}
            ${EndIf}
        ${Loop}
    ${EndIf}
    StrCpy $FinalPort $Port
FunctionEnd


# 管理端口
Function ManagePorts
    ; 实例A端口检测（固定1433）
    nsExec::ExecToStack 'netstat -ano | findstr :1433'
    Pop $0
    ${If} $0 == 0
        StrCpy $R1 "conflict"  ; 标记端口冲突
    ${EndIf}

    ; 实例B动态分配（初始尝试1434）
    ${For} $1 1434 1533
        nsExec::ExecToStack `netsh interface ipv4 show excludedportrange protocol=tcp | findstr /C:"$1 "`
        Pop $0
        ${If} $0 != 0
            StrCpy $R2 $1  ; 分配可用端口
            ${ExitFor}
        ${EndIf}
    ${Next}
FunctionEnd

!macro CheckFixedInstance INSTANCE_NAME RESULT_VAR
    ; 方法1：通过服务检测
    nsExec::ExecToStack 'sc query MSSQL$${INSTANCE_NAME}'
    Pop ${RESULT_VAR}
    ${If} ${RESULT_VAR} == 0
        StrCpy ${RESULT_VAR} "exist"
    ${Else}
        ; 方法2：注册表深度检测
        ReadRegStr $0 HKLM "SOFTWARE\Microsoft\Microsoft SQL Server\Instance Names\SQL" "${INSTANCE_NAME}"
        ${If} $0 != ""
            StrCpy ${RESULT_VAR} "exist"
        ${EndIf}
    ${EndIf}
!macroend

!macro BuildConfigFile INSTANCE PORT
    FileOpen $0 "$PLUGINSDIR\${INSTANCE}_Config.ini"  w
    FileWrite $0 "[OPTIONS]$\r$\n"
    FileWrite $0 "ACTION=Install$\r$\n"
    FileWrite $0 "FEATURES=SQLENGINE$\r$\n"
    FileWrite $0 "INSTANCENAME=${INSTANCE}$\r$\n"
    FileWrite $0 "SQLSVCACCOUNT=`"NT Service\MSSQL$${INSTANCE}`"$\r$\n"
    FileWrite $0 "TCPENABLED=1$\r$\n"
    FileWrite $0 "TCPPORT=${PORT}$\r$\n"
    FileWrite $0 "SECURITYMODE=SQL$\r$\n"
    FileWrite $0 "SAPWD=`"$9`"$\r$\n"  ; 从输入框获取密码
    FileClose $0
!macroend