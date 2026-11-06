# ========================================================
# WHATSAPP AUTO SENDER - POWERSHELL ENGINE
# Mendukung WhatsApp Aplikasi (Windows Desktop) & WhatsApp Web
# ========================================================

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$Host.UI.RawUI.WindowTitle = "WhatsApp Auto Sender"

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Web -ErrorAction SilentlyContinue

# Definisi Win32 API untuk Window Management & Keystrokes
Add-Type @'
using System;
using System.Runtime.InteropServices;
using System.Diagnostics;
using System.Text;

public class Win32Helper {
    [DllImport("user32.dll")]
    public static extern bool SetForegroundWindow(IntPtr hWnd);

    [DllImport("user32.dll")]
    public static extern void SwitchToThisWindow(IntPtr hWnd, bool fAltTab);

    [DllImport("user32.dll")]
    public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);

    [DllImport("user32.dll")]
    public static extern IntPtr GetForegroundWindow();

    [DllImport("kernel32.dll")]
    public static extern IntPtr GetConsoleWindow();

    [DllImport("user32.dll")]
    public static extern void keybd_event(byte bVk, byte bScan, uint dwFlags, UIntPtr dwExtraInfo);

    [DllImport("user32.dll")]
    public static extern bool EnumWindows(EnumWindowsProc lpEnumFunc, IntPtr lParam);
    public delegate bool EnumWindowsProc(IntPtr hWnd, IntPtr lParam);

    [DllImport("user32.dll", CharSet = CharSet.Auto)]
    public static extern int GetWindowText(IntPtr hWnd, StringBuilder lpString, int nMaxCount);

    [DllImport("user32.dll")]
    public static extern bool IsWindowVisible(IntPtr hWnd);

    [DllImport("user32.dll")]
    public static extern uint GetWindowThreadProcessId(IntPtr hWnd, out uint lpdwProcessId);

    public const byte VK_RETURN = 0x0D;
    public const byte VK_CONTROL = 0x11;
    public const uint KEYEVENTF_KEYUP = 0x0002;

    public static void SendEnterKey() {
        keybd_event(VK_RETURN, 0, 0, UIntPtr.Zero);
        System.Threading.Thread.Sleep(80);
        keybd_event(VK_RETURN, 0, KEYEVENTF_KEYUP, UIntPtr.Zero);
    }

    public static IntPtr FindAppWindow(string searchTitle) {
        IntPtr found = IntPtr.Zero;
        EnumWindows((hWnd, lParam) => {
            if (IsWindowVisible(hWnd)) {
                StringBuilder sb = new StringBuilder(256);
                GetWindowText(hWnd, sb, 256);
                string title = sb.ToString();
                if (!string.IsNullOrEmpty(title) && title.IndexOf(searchTitle, StringComparison.OrdinalIgnoreCase) >= 0) {
                    found = hWnd;
                    return false;
                }
            }
            return true;
        }, IntPtr.Zero);
        return found;
    }
}
'@

function Show-Header {
    Clear-Host
    Write-Host "============================================================" -ForegroundColor Cyan
    Write-Host "          WHATSAPP BROADCAST / AUTO SENDER v1.1             " -ForegroundColor Yellow
    Write-Host "============================================================" -ForegroundColor Cyan
    Write-Host " Mendukung WhatsApp Aplikasi (Desktop) & WhatsApp Web       " -ForegroundColor Gray
    Write-Host "============================================================" -ForegroundColor Cyan
    Write-Host ""
}

Show-Header

$ScriptDir = $PSScriptRoot
if (-not $ScriptDir) {
    $ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
}

$TemplateFile    = Join-Path $ScriptDir "template.txt"
$TemplatePakFile = Join-Path $ScriptDir "template_pak.txt"
$TemplateBuFile  = Join-Path $ScriptDir "template_bu.txt"
$NomorFile       = Join-Path $ScriptDir "nomor.txt"
$LogFile         = Join-Path $ScriptDir "riwayat_kirim.log"

# 1. Pengecekan Template (Mendukung Template Ganda: Pak & Bu, atau Template Tunggal)
$HasDualTemplates = (Test-Path $TemplatePakFile) -and (Test-Path $TemplateBuFile)

if ($HasDualTemplates) {
    $TemplatePakContent = [System.IO.File]::ReadAllText($TemplatePakFile, [System.Text.Encoding]::UTF8).Trim()
    $TemplateBuContent  = [System.IO.File]::ReadAllText($TemplateBuFile, [System.Text.Encoding]::UTF8).Trim()
} elseif (Test-Path $TemplateFile) {
    $TemplateContent = [System.IO.File]::ReadAllText($TemplateFile, [System.Text.Encoding]::UTF8).Trim()
    if ([string]::IsNullOrWhiteSpace($TemplateContent)) {
        Write-Host "[!] File template.txt masih kosong!" -ForegroundColor Red
        Write-Host "    Silakan isi pesan template terlebih dahulu." -ForegroundColor Yellow
        Write-Host ""
        Read-Host "Tekan [Enter] untuk keluar..."
        exit 1
    }
} else {
    Write-Host "[!] File template tidak ditemukan!" -ForegroundColor Red
    Write-Host "    Silakan sediakan template_pak.txt & template_bu.txt (atau template.txt)." -ForegroundColor Yellow
    Write-Host ""
    Read-Host "Tekan [Enter] untuk keluar..."
    exit 1
}

# 2. Pengecekan File nomor.txt
if (-not (Test-Path $NomorFile)) {
    Write-Host "[!] File nomor.txt tidak ditemukan!" -ForegroundColor Red
    Write-Host "    Silakan buat file nomor.txt di folder yang sama." -ForegroundColor Yellow
    Write-Host ""
    Read-Host "Tekan [Enter] untuk keluar..."
    exit 1
}

$RawLines = [System.IO.File]::ReadAllLines($NomorFile, [System.Text.Encoding]::UTF8)
$TargetList = @()

foreach ($line in $RawLines) {
    $trimmed = $line.Trim()
    if ([string]::IsNullOrWhiteSpace($trimmed) -or $trimmed.StartsWith("#") -or $trimmed.StartsWith("//")) {
        continue
    }

    $phone = ""
    $name  = ""

    # Mendukung pemisah: koma (,), titik koma (;), pipa (|), atau tab (\t)
    if ($trimmed -match "[,;|\t]") {
        $parts = $trimmed -split "[,;|\t]", 2
        $part0 = $parts[0].Trim()
        $part1 = $parts[1].Trim()

        $clean0 = $part0 -replace "[^\d]", ""
        $clean1 = $part1 -replace "[^\d]", ""

        # Deteksi otomatis: mana yang nomor dan mana yang nama
        if ($clean0.Length -ge 9 -and $clean1.Length -lt 9) {
            $phone = $part0
            $name  = $part1
        } elseif ($clean1.Length -ge 9 -and $clean0.Length -lt 9) {
            $phone = $part1
            $name  = $part0
        } else {
            $phone = $part0
            $name  = $part1
        }
    } else {
        $phone = $trimmed
        $name  = ""
    }

    # Bersihkan nomor telepon (hanya digit)
    $clean = $phone -replace "[^\d]", ""
    if ($clean.StartsWith("0")) {
        $clean = "62" + $clean.Substring(1)
    } elseif ($clean.StartsWith("8")) {
        $clean = "62" + $clean
    }

    # Validasi panjang nomor (minimal 9 digit)
    if ($clean.Length -ge 9) {
        $TargetList += [PSCustomObject]@{
            NomorAsli = $phone
            Nomor     = $clean
            Nama      = $name
        }
    }
}

if ($TargetList.Count -eq 0) {
    Write-Host "[!] Tidak ada nomor tujuan yang valid di nomor.txt!" -ForegroundColor Red
    Write-Host "    Pastikan nomor sudah diisi (contoh: 08123456789, Pak Faiz)." -ForegroundColor Yellow
    Write-Host ""
    Read-Host "Tekan [Enter] untuk keluar..."
    exit 1
}

# Tampilkan Ringkasan & Preview Kontak
if ($HasDualTemplates) {
    Write-Host "[OK] Template GANDA (Pak & Bu) berhasil dimuat!" -ForegroundColor Green
    Write-Host "---------------- PREVIEW TEMPLATE (PAK) ----------------" -ForegroundColor DarkGray
    Write-Host $TemplatePakContent -ForegroundColor Gray
    Write-Host "---------------- PREVIEW TEMPLATE (BU) -----------------" -ForegroundColor DarkGray
    Write-Host $TemplateBuContent -ForegroundColor Gray
    Write-Host "--------------------------------------------------------" -ForegroundColor DarkGray
} else {
    Write-Host "[OK] Template berhasil dimuat!" -ForegroundColor Green
    Write-Host "------------------- PREVIEW TEMPLATE -------------------" -ForegroundColor DarkGray
    Write-Host $TemplateContent -ForegroundColor Gray
    Write-Host "--------------------------------------------------------" -ForegroundColor DarkGray
}
Write-Host "[OK] Ditemukan $($TargetList.Count) nomor target di nomor.txt:" -ForegroundColor Green

# Tampilkan daftar kontak dan nama yang terdeteksi
$previewCount = [Math]::Min($TargetList.Count, 10)
for ($i = 0; $i -lt $previewCount; $i++) {
    $t = $TargetList[$i]
    $displayName = if ($t.Nama) { $t.Nama } else { "(Tanpa nama khusus)" }
    Write-Host "  $($i + 1). $($t.Nomor) -> Nama: $displayName" -ForegroundColor Gray
}
if ($TargetList.Count -gt 10) {
    Write-Host "  ... dan $($TargetList.Count - 10) kontak lainnya." -ForegroundColor DarkGray
}
Write-Host ""

# Pilihan Target WhatsApp
Write-Host "Pilih Tujuan WhatsApp:" -ForegroundColor Yellow
Write-Host "  [1] WhatsApp Aplikasi (Desktop / Windows App) - [Default]" -ForegroundColor White
Write-Host "  [2] WhatsApp Web (Buka via Browser Default)" -ForegroundColor White
$TargetAppInput = Read-Host "Pilihan Anda (1/2, default: 1)"
$UseDesktopApp = $true
if ($TargetAppInput.Trim() -eq "2") {
    $UseDesktopApp = $false
}

Write-Host ""
# Pilihan Mode Pengiriman
Write-Host "Pilih Mode Pengiriman:" -ForegroundColor Yellow
Write-Host "  [1] Otomatis (Buka -> Fokus ke WhatsApp -> Otomatis tekan Enter)" -ForegroundColor White
Write-Host "  [2] Semi-Otomatis (Buka -> Cek manual -> Tekan Enter di console untuk lanjut)" -ForegroundColor White
$ModeInput = Read-Host "Pilihan Anda (1/2, default: 1)"
$IsAutoMode = $true
if ($ModeInput.Trim() -eq "2") {
    $IsAutoMode = $false
}

$LoadDelay = 7
$MinDelay  = 5
$MaxDelay  = 10

if ($IsAutoMode) {
    Write-Host ""
    Write-Host "[INFO] Untuk nomor baru/belum disimpan, WhatsApp butuh 6-8 detik untuk memuat chat." -ForegroundColor DarkGray
    $inputLoad = Read-Host "Waktu tunggu WhatsApp siap sebelum kirim Enter (detik, default: 7)"
    if ($inputLoad -match "^\d+$" -and [int]$inputLoad -gt 1) {
        $LoadDelay = [int]$inputLoad
    }

    Write-Host ""
    Write-Host "[INFO] Jeda acak (randomizer) antar kontak untuk keamanan dari spam filter WhatsApp." -ForegroundColor DarkGray
    $inputRange = Read-Host "Rentang jeda acak antar kontak (detik, default: 5-10)"
    if ($inputRange -match "^\s*(\d+)\s*[-,\s]\s*(\d+)\s*$") {
        $parsedMin = [int]$matches[1]
        $parsedMax = [int]$matches[2]
        if ($parsedMin -gt 0 -and $parsedMax -ge $parsedMin) {
            $MinDelay = $parsedMin
            $MaxDelay = $parsedMax
        }
    } elseif ($inputRange -match "^\d+$" -and [int]$inputRange -gt 0) {
        $val = [int]$inputRange
        $MinDelay = $val
        $MaxDelay = $val
    }
}

Write-Host ""
Write-Host "--------------------------------------------------------" -ForegroundColor DarkGray
Write-Host " Target WhatsApp : $(if ($UseDesktopApp) { 'WhatsApp Desktop App' } else { 'WhatsApp Web' })" -ForegroundColor Cyan
Write-Host " Mode Kirim      : $(if ($IsAutoMode) { 'Otomatis' } else { 'Semi-Otomatis (Manual)' })" -ForegroundColor Cyan
if ($IsAutoMode) {
    Write-Host " Delay Load      : $LoadDelay detik" -ForegroundColor Cyan
    Write-Host " Jeda Antar Chat : Random $MinDelay s/d $MaxDelay detik" -ForegroundColor Cyan
}
Write-Host " Total Target    : $($TargetList.Count) kontak" -ForegroundColor Cyan
Write-Host "--------------------------------------------------------" -ForegroundColor DarkGray
Write-Host ""

$Confirm = Read-Host "Mulai proses pengiriman sekarang? (Y/n)"
if ($Confirm.Trim().ToLower() -eq "n") {
    Write-Host "Proses dibatalkan oleh pengguna." -ForegroundColor Yellow
    exit 0
}

Write-Host ""
Write-Host ">> MEMULAI PENGIRIMAN..." -ForegroundColor Green
Write-Host ""

$SuccessCount = 0
$Index = 0

foreach ($target in $TargetList) {
    $Index++
    $targetPhone = $target.Nomor
    $targetName  = $target.Nama

    # Deteksi Gender Kontak (Pak vs Bu vs Generic)
    $isGeneric = ($targetName -match '(?i)Bapak\/Ibu|Pak\/Bu') -or [string]::IsNullOrWhiteSpace($targetName)
    $isBu = (-not $isGeneric) -and ($targetName -match '(?i)\b(bu|ibu)\b')

    # Pemilihan Template
    if ($HasDualTemplates) {
        if ($isGeneric -and (Test-Path $TemplateFile)) {
            $msg = [System.IO.File]::ReadAllText($TemplateFile, [System.Text.Encoding]::UTF8).Trim()
        } else {
            $msg = if ($isBu) { $TemplateBuContent } else { $TemplatePakContent }
        }
    } else {
        $msg = $TemplateContent
        # Auto-adjust jika menggunakan template tunggal
        if ($isBu) {
            $msg = $msg -replace '(?i)Bapak\/Ibu', 'Ibu'
            $msg = $msg -replace '(?i)Pak\/Bu', 'Bu'
        } else {
            $msg = $msg -replace '(?i)Bapak\/Ibu', 'Bapak'
            $msg = $msg -replace '(?i)Pak\/Bu', 'Pak'
        }
    }

    # Personalisasi Nama Target
    if ($targetName) {
        $msg = $msg -replace '(?i)(Pak\/Bu\s*|Bapak\/Ibu\s*|Pak\s*|Bu\s*)?(\[Nama Lengkap\]|\{Nama Lengkap\}|\[Nama Panggilan\]|\{Nama Panggilan\}|\[nama\]|\{nama\}|\[name\]|\{name\})', $targetName
    } else {
        $defaultSalutation = if ($isBu) { 'Ibu' } else { 'Bapak' }
        $msg = $msg -replace '(?i)(Pak\/Bu\s*|Bapak\/Ibu\s*|Pak\s*|Bu\s*)?(\[Nama Lengkap\]|\{Nama Lengkap\}|\[Nama Panggilan\]|\{Nama Panggilan\}|\[nama\]|\{nama\}|\[name\]|\{name\})', $defaultSalutation
    }
    $msg = $msg -replace '\{nomor\}|\[nomor\]|\{phone\}|\[phone\]', $targetPhone

    $firstLine = ($msg -split "[\r\n]")[0].Trim()
    if ($firstLine.Length -gt 50) { $firstLine = $firstLine.Substring(0, 47) + "..." }

    Write-Host "[$Index/$($TargetList.Count)] Target : $targetPhone $(if ($targetName) { "($targetName)" })" -ForegroundColor White
    Write-Host "         Pesan  : `"$firstLine`"" -ForegroundColor DarkCyan

    # URL Encoding yang aman untuk WhatsApp
    $encodedText = [System.Uri]::EscapeDataString($msg)

    # Susun URL/URI
    if ($UseDesktopApp) {
        $waUrl = "whatsapp://send?phone=$targetPhone&text=$encodedText"
    } else {
        $waUrl = "https://web.whatsapp.com/send?phone=$targetPhone&text=$encodedText"
    }

    try {
        # Buka WhatsApp
        Start-Process $waUrl
    } catch {
        Write-Host "  [!] Gagal membuka WhatsApp: $_" -ForegroundColor Red
        continue
    }

    if ($IsAutoMode) {
        # Hitung mundur loading WhatsApp
        for ($s = $LoadDelay; $s -gt 0; $s--) {
            Write-Host -NoNewline "`r  [..] Menunggu WhatsApp memuat chat... ($s detik) "
            Start-Sleep -Seconds 1
        }
        Write-Host "`r  [>>] Memfokuskan WhatsApp & Mengirim pesan via Enter... " -ForegroundColor Green

        # 1. Dapatkan handle jendela CMD saat ini
        $consoleHwnd = [Win32Helper]::GetConsoleWindow()

        # 2. Minimalkan jendela CMD sejenak agar WhatsApp otomatis naik ke depan (foreground)
        if ($consoleHwnd -ne [IntPtr]::Zero) {
            [Win32Helper]::ShowWindow($consoleHwnd, 6) # SW_MINIMIZE = 6
            Start-Sleep -Milliseconds 500
        }

        # 3. Paksa fokus ke WhatsApp
        $waHwnd = [Win32Helper]::FindAppWindow("WhatsApp")
        if ($waHwnd -ne [IntPtr]::Zero) {
            [Win32Helper]::ShowWindow($waHwnd, 9) # SW_RESTORE
            [Win32Helper]::SwitchToThisWindow($waHwnd, $true)
            [Win32Helper]::SetForegroundWindow($waHwnd)
            Start-Sleep -Milliseconds 400
        }

        # 4. Kirim tombol Enter (hardware event + managed SendKeys)
        [Win32Helper]::SendEnterKey()
        Start-Sleep -Milliseconds 200
        [System.Windows.Forms.SendKeys]::SendWait("{ENTER}")
        Start-Sleep -Milliseconds 600

        # 5. Kembalikan jendela CMD ke layar agar user melihat progres
        if ($consoleHwnd -ne [IntPtr]::Zero) {
            [Win32Helper]::ShowWindow($consoleHwnd, 9) # SW_RESTORE = 9
            [Win32Helper]::SetForegroundWindow($consoleHwnd)
            Start-Sleep -Milliseconds 200
        }

        # Catat ke log
        $timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
        $logEntry = "[$timestamp] SUKSES | $targetPhone | $targetName"
        Add-Content -Path $LogFile -Value $logEntry -Encoding UTF8
        $SuccessCount++

        # Jeda acak (randomizer) antar pesan
        if ($Index -lt $TargetList.Count) {
            $randomInterval = if ($MinDelay -eq $MaxDelay) { $MinDelay } else { Get-Random -Minimum $MinDelay -Maximum ($MaxDelay + 1) }
            for ($s = $randomInterval; $s -gt 0; $s--) {
                Write-Host -NoNewline "`r  [~] Jeda acak ($randomInterval detik): menunggu... ($s detik) "
                Start-Sleep -Seconds 1
            }
            Write-Host "`r  [OK] Siap untuk kontak berikutnya.                              " -ForegroundColor DarkGray
        }
    } else {
        # Mode Semi-Otomatis
        Write-Host "  [>] WhatsApp telah dibuka untuk nomor ini." -ForegroundColor Yellow
        Write-Host "  [*] Cek pesan di WhatsApp, lalu tekan [ENTER] di sini untuk lanjut (atau ketik q untuk stop): " -ForegroundColor Cyan -NoNewline
        $ans = Read-Host
        
        $timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
        $logEntry = "[$timestamp] DIBUKA | $targetPhone | $targetName"
        Add-Content -Path $LogFile -Value $logEntry -Encoding UTF8
        $SuccessCount++

        if ($ans -and $ans.Trim().ToLower() -eq "q") {
            Write-Host ""
            Write-Host "[!] Pengiriman dihentikan oleh pengguna." -ForegroundColor Yellow
            break
        }
    }
    Write-Host ""
}

Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "                  PENGIRIMAN SELESAI!                       " -ForegroundColor Green
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host " Total diproses: $SuccessCount dari $($TargetList.Count) nomor." -ForegroundColor White
Write-Host " Riwayat log tersimpan di: $LogFile" -ForegroundColor Gray
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host ""
