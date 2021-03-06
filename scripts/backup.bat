call:%*
goto:eof

REM #####################
REM ## BACKUP
REM #####################
:inspectPartition
if "!backup_taPartitionName!" == "-1" goto:eof
	echo --- %1 ---
	set /p "=Searching for Serial No..." < nul
	tools\adb shell su -c "%BB% cat /dev/block/%1 | %BB% grep -s -m 1 -c '!backup_serialno!'">tmpbak\backup_matchSerial
	set /p backup_matchSerial=<tmpbak\backup_matchSerial
	if "!backup_matchSerial!" == "1" (
		echo +
	) else (
		echo -
	)
	set /p "=Searching for Marlin Certificate..." < nul
	tools\adb shell su -c "%BB% cat /dev/block/%1 | %BB% grep -s -m 1 -c -i 'marlin:datacertification'">tmpbak\backup_matchMarlin
	set /p backup_matchMarlin=<tmpbak\backup_matchMarlin
	if "!backup_matchMarlin!" == "1" (
		echo +
	) else (
		echo -
	)

	if "!backup_matchSerial!" == "1" (
		if "!backup_matchMarlin!" == "1" (
			if "!backup_taPartitionName!" == "" (
				set backup_taPartitionName=%1
			) else (
				set backup_taPartitionName=-1
				
			)
		)
	)
	echo.
	goto:eof
)

:backupTA
echo.
if NOT exist backup mkdir backup > nul 2>&1
call scripts\adb.bat wakeDevice
echo.
echo =======================================
echo  FIND TA PARTITION
echo =======================================
tools\adb shell su -c "%BB% ls -l %PARTITION_BY_NAME% | %BB% awk '{print \$11}'">tmpbak\backup_defaultTA
set /p backup_defaultTA=<tmpbak\backup_defaultTA
tools\adb shell su -c "if [ -b '!backup_defaultTA!' ]; then echo '1'; else echo '0'; fi">tmpbak\backup_defaultTAvalid
set /p backup_defaultTAvalid=<tmpbak\backup_defaultTAvalid
if "!backup_defaultTAvalid!" == "1" (
	set partition=!backup_defaultTA!
	echo Partition found^^!
) else (
	echo Partition not found by name.
	echo.
	%CHOICE% /c:yn %CHOICE_TEXT_PARAM% "Do you want to perform an extensive search for the TA?"
	if errorlevel 2 goto onBackupCancelled
	
	tools\adb get-serialno>tmpbak\backup_serialno
	set /p backup_serialno=<tmpbak\backup_serialno

	echo.
	echo =======================================
	echo  INSPECTING PARTITIONS
	echo =======================================
	set backup_taPartitionName=
	tools\adb shell su -c "%BB% cat /proc/partitions | %BB% awk '{if (\$3<=9999 && match (\$4, \"'\"mmcblk\"'\")) print \$4}'">tmpbak\backup_potentialPartitions
	for /F "tokens=*" %%A in (tmpbak\backup_potentialPartitions) do call:inspectPartition %%A
	
	if NOT "!backup_taPartitionName!" == "" (
		if NOT "!backup_taPartitionName!" == "-1" (
			echo Partition found^^!
			set partition=/dev/block/!backup_taPartitionName!
		) else (
				echo *** More than one partition match the TA partition search criteria. ***
				echo *** Therefore it is not possible to determine which one or ones to use. ***
				echo *** Contact DevShaft @XDA-forums for support. ***
			goto onBackupCancelled
		)
	) else (
		echo *** No compatible TA partition found on your device. ***
		goto onBackupCancelled
	)
	
)

echo.
echo =======================================
echo  BACKUP TA PARTITION
echo =======================================
tools\adb shell su -c "%BB% md5sum !partition! | %BB% awk {'print \$1'}">tmpbak\backup_currentPartitionMD5
tools\adb shell su -c "%BB% dd if=!partition! of=/sdcard/backupTA.img"

echo.
echo =======================================
echo  INTEGRITY CHECK
echo =======================================
tools\adb shell su -c "%BB% md5sum /sdcard/backupTA.img | %BB% awk {'print \$1'}">tmpbak\backup_backupMD5
set /p backup_currentPartitionMD5=<tmpbak\backup_currentPartitionMD5
set /p backup_backupMD5=<tmpbak\backup_backupMD5
verify > nul
if NOT "!backup_currentPartitionMD5!" == "!backup_backupMD5!" (
	echo FAILED
	goto onBackupFailed
) else (
	echo OK
)

echo.
echo =======================================
echo  PULL BACKUP FROM SDCARD
echo =======================================
tools\adb pull /sdcard/backupTA.img tmpbak\TA.img
if NOT "%errorlevel%" == "0" goto onBackupFailed

echo.
echo =======================================
echo  INTEGRITY CHECK
echo =======================================
tools\md5 -l -n tmpbak\TA.img>tmpbak\backup_backupPulledMD5
if NOT "%errorlevel%" == "0" goto onBackupFailed
set /p backup_backupPulledMD5=<tmpbak\backup_backupPulledMD5
verify > nul
if NOT "!backup_currentPartitionMD5!" == "!backup_backupPulledMD5!" (
	echo FAILED
	goto onBackupFailed
) else (
	echo OK
)

echo.
echo =======================================
echo  PACKAGE BACKUP
echo =======================================
echo !partition!>tmpbak\TA.blk
echo !backup_backupPulledMD5!>tmpbak\TA.md5
tools\adb shell su -c "%BB% date +%%Y%%m%%d.%%H%%M%%S">tmpbak\backup_timestamp
set /p backup_timestamp=<tmpbak\backup_timestamp
cd tmpbak
..\tools\zip a ..\backup\TA-backup-!backup_timestamp!.zip TA.img TA.md5 TA.blk
if NOT "%errorlevel%" == "0" goto onBackupFailed
cd..

call:exit 1
goto:eof

REM #####################
REM ## BACKUP CANCELLED
REM #####################
:onBackupCancelled
call:exit 2
goto:eof

REM #####################
REM ## BACKUP FAILED
REM #####################
:onBackupFailed
call:exit 3
goto:eof

REM #####################
REM ## EXIT BACKUP
REM #####################
:exit
call:dispose %~1
echo.
if "%~1" == "1" echo *** Backup successful. ***
if "%~1" == "2" echo *** Backup cancelled. ***
if "%~1" == "3" echo *** Backup unsuccessful. ***
echo.
pause
goto:eof

REM #####################
REM ## DISPOSE BACKUP
REM #####################
:dispose
set backup_currentPartitionMD5=
set backup_backupMD5=
set backup_backupPulledMD5=
set backup_defaultTA=
set backup_defaultTAvalid=
set backup_matchSerial=
set backup_matchMarlin=
set backup_taPartitionName=
set backup_TAByName=
set partition=

if "%~1" == "1" del /q /s tmpbak\backup_*.* > nul 2>&1

tools\adb shell rm /sdcard/backupTA.img > nul 2>&1
goto:eof