# Drives a DMOS live session in VMware Workstation from Windows, through vmrun and VMware Tools.
#   .\scripts\test_vmware.ps1 start                          boots the VM without a window
#   .\scripts\test_vmware.ps1 wait                           waits until VMware Tools answer
#   .\scripts\test_vmware.ps1 shot  <out.png>
#   .\scripts\test_vmware.ps1 run   "<shell command>"        runs in the graphical session, returns at once
#   .\scripts\test_vmware.ps1 out   "<shell command>"        runs, waits, and prints the command's output
#   .\scripts\test_vmware.ps1 put   <host file> <guest path> copies a file into the guest
#   .\scripts\test_vmware.ps1 script <host bash script>      copies a script in, runs it, prints its output
#   .\scripts\test_vmware.ps1 input "click 960 540 type ola key enter"
#                                                            real clicks and keys (see guest_input.py)
#   .\scripts\test_vmware.ps1 stop
# Uses the live account (dmos / live), so it only works on the live ISO, not on an installed system.
param(
    [Parameter(Mandatory)][ValidateSet("start", "wait", "shot", "run", "out", "put", "script", "input", "stop")][string]$Action,
    [string]$Arg,
    [string]$Arg2,
    [string]$Vmx = "$env:USERPROFILE\Documents\Virtual Machines\DMOS 1.2 (live)\DMOS 1.2 (live).vmx",
    [string]$Lang = "pt_PT.UTF-8"
)
$ErrorActionPreference = "Stop"
$vmrun = "C:\Program Files\VMware\VMware Workstation\vmrun.exe"
$guest = @("-T", "ws", "-gu", "dmos", "-gp", "live")
# The Plasma session's environment, which vmrun does not provide: copied from plasmashell
# (it has XAUTHORITY and the rest), with a minimal fallback for before the shell is up.
$envs = "export XDG_RUNTIME_DIR=/run/user/1000 WAYLAND_DISPLAY=wayland-0 DISPLAY=:0 " +
        "DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/1000/bus XDG_CURRENT_DESKTOP=KDE " +
        "XDG_SESSION_TYPE=wayland KDE_FULL_SESSION=true KDE_SESSION_VERSION=6; " +
        "p=`$(pgrep -u dmos -x plasmashell | head -1); " +
        "if [ -n `"`$p`" ]; then while IFS= read -r -d '' kv; do export `"`$kv`"; done < /proc/`$p/environ; fi; " +
        "export LANG=$Lang"

switch ($Action) {
    "start" {
        & $vmrun -T ws start $Vmx nogui
        if ($LASTEXITCODE -ne 0) { throw "start failed" }
    }
    "stop" {
        & $vmrun -T ws stop $Vmx hard
    }
    "wait" {
        # checkToolsState answers "unknown" for a VM started without a window, so ask the guest itself.
        $ErrorActionPreference = "Continue"
        for ($i = 0; $i -lt 60; $i++) {
            & $vmrun @guest runProgramInGuest $Vmx /bin/bash -c "test -S /run/user/1000/wayland-0" 2>$null | Out-Null
            if ($LASTEXITCODE -eq 0) { return "session running" }
            Start-Sleep 5
        }
        throw "The live session did not start"
    }
    "shot" {
        & $vmrun @guest captureScreen $Vmx $Arg
        if ($LASTEXITCODE -ne 0) { throw "captureScreen failed" }
    }
    "run" {
        & $vmrun @guest runProgramInGuest $Vmx -noWait /bin/bash -c "$envs; $Arg >/tmp/vmrun-cmd.log 2>&1"
        if ($LASTEXITCODE -ne 0) { throw "runProgramInGuest failed" }
    }
    "out" {
        & $vmrun @guest runProgramInGuest $Vmx /bin/bash -c "$envs; { $Arg ; } >/tmp/vmrun-out.txt 2>&1"
        $local = Join-Path $env:TEMP "vmrun-out-$PID.txt"
        & $vmrun @guest CopyFileFromGuestToHost $Vmx /tmp/vmrun-out.txt $local
        if (Test-Path $local) { Get-Content $local -Encoding UTF8; Remove-Item $local }
    }
    "put" {
        & $vmrun @guest CopyFileFromHostToGuest $Vmx $Arg $Arg2
        if ($LASTEXITCODE -ne 0) { throw "CopyFileFromHostToGuest failed" }
    }
    "script" {
        # Runs a host bash script inside the session and prints what it wrote. Quoting-proof.
        & $vmrun @guest CopyFileFromHostToGuest $Vmx $Arg /tmp/vmrun-script.sh
        & $vmrun @guest runProgramInGuest $Vmx /bin/bash -c "$envs; bash /tmp/vmrun-script.sh >/tmp/vmrun-out.txt 2>&1"
        $local = Join-Path $env:TEMP "vmrun-out-$PID.txt"
        & $vmrun @guest CopyFileFromGuestToHost $Vmx /tmp/vmrun-out.txt $local
        if (Test-Path $local) { Get-Content $local -Encoding UTF8; Remove-Item $local }
    }
    "input" {
        # vmrun cannot click or type, so a small uinput script does it from inside the guest.
        # It needs python3-evdev, fetched on first use (the live session has to be online).
        & $vmrun @guest CopyFileFromHostToGuest $Vmx (Join-Path $PSScriptRoot "guest_input.py") /tmp/guest_input.py
        & $vmrun @guest runProgramInGuest $Vmx /bin/bash -c ("python3 -c 'import evdev' 2>/dev/null || " +
            "{ sudo apt-get update -q; sudo DEBIAN_FRONTEND=noninteractive apt-get install -y -q python3-evdev; } >/tmp/evdev-install.log 2>&1; " +
            "sudo python3 /tmp/guest_input.py $Arg")
        if ($LASTEXITCODE -ne 0) { throw "guest_input.py failed" }
    }
}
