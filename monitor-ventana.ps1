# ============================================================
#  Mantiene un tamanio MINIMO para la ventana "Mis Tareas".
#  Corrige muchas veces por segundo para que, al arrastrar,
#  la ventana NO pueda bajar del limite (tope duro).
#  Se cierra solo cuando la ventana se cierra.
# ============================================================
$minW = 360   # ancho minimo en px CSS (se ajusta al DPI)
$minH = 420   # alto  minimo en px CSS

Add-Type @'
using System;
using System.Runtime.InteropServices;
namespace WinMon {
  [StructLayout(LayoutKind.Sequential)] public struct RECT { public int Left, Top, Right, Bottom; }
  public static class U {
    [DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern IntPtr FindWindow(string c, string t);
    [DllImport("user32.dll")] public static extern bool IsWindow(IntPtr h);
    [DllImport("user32.dll")] public static extern bool MoveWindow(IntPtr h,int x,int y,int w,int ht,bool repaint);
    [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out RECT r);
    [DllImport("user32.dll")] public static extern uint GetDpiForWindow(IntPtr h);
  }
}
'@

$hwnd=[IntPtr]::Zero; $mw=0; $mh=0
$seen=$false; $gone=0; $waited=0

while($true){
  Start-Sleep -Milliseconds 16   # ~60 veces por segundo

  # (re)localizar la ventana si hace falta
  if($hwnd -eq [IntPtr]::Zero -or -not [WinMon.U]::IsWindow($hwnd)){
    $hwnd=[WinMon.U]::FindWindow([NullString]::Value, "Mis Tareas")
    if($hwnd -eq [IntPtr]::Zero){
      if($seen){ $gone++; if($gone -gt 300){ break } }      # ~5s cerrada => salir
      else { $waited++; if($waited -gt 1800){ break } }      # nunca aparecio (~30s) => salir
      continue
    }
    $seen=$true; $gone=0
    $dpi=[WinMon.U]::GetDpiForWindow($hwnd); if($dpi -le 0){ $dpi=96 }
    $sc=$dpi/96.0; $mw=[int]($minW*$sc); $mh=[int]($minH*$sc)
  }

  $r=New-Object WinMon.RECT
  if(-not [WinMon.U]::GetWindowRect($hwnd,[ref]$r)){ $hwnd=[IntPtr]::Zero; continue }
  $w=$r.Right-$r.Left; $ht=$r.Bottom-$r.Top
  if($w -lt $mw -or $ht -lt $mh){
    [WinMon.U]::MoveWindow($hwnd, $r.Left, $r.Top, [Math]::Max($w,$mw), [Math]::Max($ht,$mh), $true) | Out-Null
  }
}
