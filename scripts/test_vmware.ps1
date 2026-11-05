# Drives a DMOS live session in VMware Workstation from Windows, through vmrun and VMware Tools.
#   .\scripts\test_vmware.ps1 shot  <out.png>
#   .\scripts\test_vmware.ps1 run   "<shell command>"        runs in the graphical session, returns at once
#   .\scripts\test_vmware.ps1 wait                           waits until VMware Tools answer
# Uses the live account (dmos / live), so it only works on the live ISO, not on an installed system.
param(
    [Parameter(Mandatory)][ValidateSet("shot", "run", "wait")][string]$Action,
    [string]$Arg,
    [string]$Vmx = "$env:USERPROFILE\Documents\Virtual Machines\DMOS 1.1 (live)\DMOS 1.1 (live).vmx"
)
$ErrorActionPreference = "Stop"
$vmrun = "C:\Program Files\VMware\VMware Workstation\vmrun.exe"
$guest = @("-T", "ws", "-gu", "dmos", "-gp", "live")

switch ($Action) {
    "wait" {
        for ($i = 0; $i -lt 60; $i++) {
            if ((& $vmrun -T ws checkToolsState $Vmx) -match "running") { return "tools running" }
            Start-Sleep 5
        }
        throw "VMware Tools did not start"
    }
    "shot" {
        & $vmrun @guest captureScreen $Vmx $Arg
        if ($LASTEXITCODE -ne 0) { throw "captureScreen failed" }
    }
    "run" {
        # The Plasma session's environment, which vmrun does not provide.
        $envs = "export XDG_RUNTIME_DIR=/run/user/1000 WAYLAND_DISPLAY=wayland-0 DISPLAY=:0 " +
                "DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/1000/bus XDG_CURRENT_DESKTOP=KDE " +
                "XDG_SESSION_TYPE=wayland KDE_FULL_SESSION=true LANG=pt_PT.UTF-8"
        & $vmrun @guest runProgramInGuest $Vmx -noWait /bin/bash -c "$envs; $Arg >/tmp/vmrun-cmd.log 2>&1"
        if ($LASTEXITCODE -ne 0) { throw "runProgramInGuest failed" }
    }
}
