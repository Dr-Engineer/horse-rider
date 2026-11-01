# Runs Godot on a separate, invisible Windows desktop, so its window never appears and can't take focus from whatever the user
# is doing. Audio is always off. Rendering still works: screenshots, autoplay and Movie Maker all come out normally.
# Use this for every run that needs pixels. Anything that doesn't is better run with --headless on the console exe.
#
#   powershell -NoProfile -ExecutionPolicy Bypass -File tools/run_hidden.ps1 -Timeout 120 -Log C:\temp\run.txt -GodotArgs "res://tests/hazard_view.tscn -- C:\temp\shots 1 0 mud 2"
#
# Adds --path <repo>, --audio-driver Dummy and --resolution 1280x720 unless GodotArgs has its own resolution. Quote any path with
# spaces inside GodotArgs. Prints the log when it ends and exits with Godot's exit code, or 124 if stopped at the timeout.
param(
	[int]$Timeout = 180,
	[string]$Log = "",
	[string]$GodotArgs = ""
)
Add-Type @"
using System;
using System.Runtime.InteropServices;
public static class HiddenDesktop {
	[StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
	public struct STARTUPINFO {
		public int cb; public string lpReserved; public string lpDesktop; public string lpTitle;
		public int dwX, dwY, dwXSize, dwYSize, dwXCountChars, dwYCountChars, dwFillAttribute, dwFlags;
		public short wShowWindow, cbReserved2; public IntPtr lpReserved2, hStdInput, hStdOutput, hStdError;
	}
	[StructLayout(LayoutKind.Sequential)]
	public struct PROCESS_INFORMATION { public IntPtr hProcess, hThread; public int dwProcessId, dwThreadId; }
	[DllImport("user32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
	public static extern IntPtr CreateDesktopW(string name, IntPtr device, IntPtr mode, int flags, uint access, IntPtr attributes);
	[DllImport("user32.dll")]
	public static extern bool CloseDesktop(IntPtr desktop);
	[DllImport("kernel32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
	public static extern bool CreateProcessW(string app, string command, IntPtr pa, IntPtr ta, bool inherit, uint flags, IntPtr env, string cwd, ref STARTUPINFO si, out PROCESS_INFORMATION pi);
	[DllImport("kernel32.dll")]
	public static extern uint WaitForSingleObject(IntPtr handle, uint ms);
	[DllImport("kernel32.dll")]
	public static extern bool GetExitCodeProcess(IntPtr handle, out uint code);
	[DllImport("kernel32.dll")]
	public static extern bool TerminateProcess(IntPtr handle, uint code);
}
"@
$repo = Split-Path -Parent $PSScriptRoot
$dir = if ($env:GODOT_DIR) { $env:GODOT_DIR } else { Join-Path $HOME "GameDev\Godot" }
$exe = Join-Path $dir "Godot_v4.7.2-stable_win64.exe"
if ($Log -eq "") {
	$Log = Join-Path ([IO.Path]::GetTempPath()) ("godot_hidden_{0}.log" -f [Guid]::NewGuid().ToString("N"))
}
$command = '"{0}" --path "{1}" --audio-driver Dummy --log-file "{2}"' -f $exe, $repo, $Log
if ($GodotArgs -notmatch "--resolution") {
	$command += " --resolution 1280x720"
}
$command += " " + $GodotArgs
$desktop = [HiddenDesktop]::CreateDesktopW("WindhorseHidden", [IntPtr]::Zero, [IntPtr]::Zero, 0, [uint32]"0x10000000", [IntPtr]::Zero)
if ($desktop -eq [IntPtr]::Zero) {
	Write-Output "run_hidden: could not create the hidden desktop, so nothing was started"
	exit 1
}
$si = New-Object HiddenDesktop+STARTUPINFO
$si.cb = [Runtime.InteropServices.Marshal]::SizeOf($si)
$si.lpDesktop = "WinSta0\WindhorseHidden"
$pi = New-Object HiddenDesktop+PROCESS_INFORMATION
if (-not [HiddenDesktop]::CreateProcessW($exe, $command, [IntPtr]::Zero, [IntPtr]::Zero, $false, 0, [IntPtr]::Zero, $repo, [ref]$si, [ref]$pi)) {
	[void][HiddenDesktop]::CloseDesktop($desktop)
	Write-Output ("run_hidden: could not start Godot, error {0}" -f [Runtime.InteropServices.Marshal]::GetLastWin32Error())
	exit 1
}
$code = 0
if ([HiddenDesktop]::WaitForSingleObject($pi.hProcess, [uint32]($Timeout * 1000)) -ne 0) {
	[void][HiddenDesktop]::TerminateProcess($pi.hProcess, 124)
	[void][HiddenDesktop]::WaitForSingleObject($pi.hProcess, 5000)
	Write-Output "run_hidden: stopped at the $Timeout s timeout"
	$code = 124
} else {
	$raw = [uint32]0
	[void][HiddenDesktop]::GetExitCodeProcess($pi.hProcess, [ref]$raw)
	$code = [int]$raw
}
[void][HiddenDesktop]::CloseDesktop($desktop)
if (Test-Path $Log) {
	Get-Content $Log | Where-Object { $_ -notmatch "ObjectDB instances were leaked|core/object/object.cpp" }
}
exit $code
