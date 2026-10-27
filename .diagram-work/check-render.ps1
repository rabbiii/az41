$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
$folder = 'C:\Users\HP\projects\az41'
[xml]$doc = [System.IO.File]::ReadAllText((Join-Path $folder 'workflow-diagram\AZ41_workflow.xml'))
$issues = [System.Collections.Generic.List[string]]::new()
foreach ($page in $doc.mxfile.diagram) {
    $height = [int]$page.mxGraphModel.pageHeight
    $bmp = [System.Drawing.Bitmap]::new(1600,$height)
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.SmoothingMode = 'AntiAlias'
    $g.TextRenderingHint = 'AntiAliasGridFit'
    $g.Clear([System.Drawing.Color]::White)
    $format = [System.Drawing.StringFormat]::GenericTypographic.Clone()
    $format.FormatFlags = [System.Drawing.StringFormatFlags]::NoWrap
    foreach ($cell in $page.mxGraphModel.root.mxCell) {
        if ($cell.id -in @('0','1')) { continue }
        $style = @{}
        foreach ($pair in $cell.style.Split(';')) { if ($pair.Contains('=')) { $kv=$pair.Split('=',2); $style[$kv[0]]=$kv[1] } }
        $geo=$cell.mxGeometry
        if ($cell.edge -eq '1') {
            $pts = @($geo.mxPoint)
            $pen = [System.Drawing.Pen]::new([System.Drawing.ColorTranslator]::FromHtml('#64748B'),2)
            $pen.CustomEndCap = [System.Drawing.Drawing2D.AdjustableArrowCap]::new(4,5)
            $g.DrawLine($pen,[single]$pts[0].x,[single]$pts[0].y,[single]$pts[1].x,[single]$pts[1].y)
            $pen.Dispose()
            continue
        }
        $x=[single]$geo.x; $y=[single]$geo.y; $w=[single]$geo.width; $h=[single]$geo.height
        if ($cell.style.StartsWith('text;')) {
            $fontStyle = if ($style.fontStyle -eq '1') { [System.Drawing.FontStyle]::Bold } else { [System.Drawing.FontStyle]::Regular }
            $font=[System.Drawing.Font]::new($style.fontFamily,[single]$style.fontSize,$fontStyle,[System.Drawing.GraphicsUnit]::Pixel)
            $brush=[System.Drawing.SolidBrush]::new([System.Drawing.ColorTranslator]::FromHtml($style.fontColor))
            $measure=$g.MeasureString([string]$cell.value,$font,10000,$format)
            if ($measure.Width -gt ($w+2)) { $issues.Add($page.name+': '+$cell.value+' | width '+[Math]::Round($measure.Width)+' > '+$w) }
            $g.DrawString([string]$cell.value,$font,$brush,[System.Drawing.PointF]::new($x,$y),$format)
            $font.Dispose(); $brush.Dispose()
        } else {
            $brush=[System.Drawing.SolidBrush]::new([System.Drawing.ColorTranslator]::FromHtml($style.fillColor))
            $pen=[System.Drawing.Pen]::new([System.Drawing.ColorTranslator]::FromHtml($style.strokeColor),1.5)
            $path=[System.Drawing.Drawing2D.GraphicsPath]::new()
            $r=if ($style.rounded -eq '1') { [single][Math]::Min(14,$h/4) } else { [single]0 }
            if ($r -gt 0) {
                $d=2*$r
                $path.AddArc($x,$y,$d,$d,180,90); $path.AddArc(($x+$w-$d),$y,$d,$d,270,90)
                $path.AddArc(($x+$w-$d),($y+$h-$d),$d,$d,0,90); $path.AddArc($x,($y+$h-$d),$d,$d,90,90)
                $path.CloseFigure()
            } else { $path.AddRectangle([System.Drawing.RectangleF]::new($x,$y,$w,$h)) }
            $g.FillPath($brush,$path); $g.DrawPath($pen,$path)
            $brush.Dispose(); $pen.Dispose(); $path.Dispose()
        }
    }
    $png=Join-Path $folder ('.diagram-work\'+$page.id+'.png')
    $bmp.Save($png,[System.Drawing.Imaging.ImageFormat]::Png)
    $g.Dispose(); $bmp.Dispose(); $format.Dispose()
    Write-Output ('Rendered '+$png)
}
if ($issues.Count -gt 0) { $issues | Write-Output; exit 1 }
Write-Output 'PASS: Every text line fits its declared width on both pages.'
