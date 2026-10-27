$ErrorActionPreference = 'Stop'
$path = 'C:\Users\HP\projects\az41\workflow-diagram\AZ41_workflow.xml'
[xml]$doc = [System.IO.File]::ReadAllText($path)
foreach ($page in $doc.mxfile.diagram) {
    $all = @($page.mxGraphModel.root.mxCell)
    $bounds = @{}
    $shapes = @()
    foreach ($c in $all) {
        if ($c.vertex -ne '1') { continue }
        $geo=$c.mxGeometry
        $r=[pscustomobject]@{id=$c.id; x=[double]$geo.x; y=[double]$geo.y; w=[double]$geo.width; h=[double]$geo.height; cell=$c}
        $bounds[$c.id]=$r
        if (-not $c.style.StartsWith('text;') -and $r.w -lt 1600) { $shapes += $r }
        if ($r.w -eq 1600) { $c.SetAttribute('style', $c.style+'locked=1;connectable=0;') }
    }
    foreach ($c in $all) {
        if ($c.vertex -ne '1' -or -not $bounds.ContainsKey($c.id)) { continue }
        $r=$bounds[$c.id]
        $containers=@($shapes | Where-Object { $_.id -ne $r.id -and $_.w*$_.h -gt $r.w*$r.h -and $_.x -le $r.x -and $_.y -le $r.y -and $_.x+$_.w -ge $r.x+$r.w -and $_.y+$_.h -ge $r.y+$r.h } | Sort-Object { $_.w*$_.h })
        if ($containers.Count -gt 0) {
            $p=$containers[0]
            $c.SetAttribute('parent',$p.id)
            $c.mxGeometry.SetAttribute('x',[string]($r.x-$p.x)); $c.mxGeometry.SetAttribute('y',[string]($r.y-$p.y))
        }
    }
    $wired=0
    foreach ($c in $all) {
        if ($c.edge -ne '1') { continue }
        $style=[string]$c.style
        foreach ($side in @('source','target')) {
            $point=@($c.mxGeometry.mxPoint | Where-Object { $_.as -eq ($side+'Point') })[0]
            $px=[double]$point.x; $py=[double]$point.y
            $candidates=@()
            foreach ($r in $shapes) {
                $cx=[Math]::Max($r.x,[Math]::Min($px,$r.x+$r.w))
                $cy=[Math]::Max($r.y,[Math]::Min($py,$r.y+$r.h))
                $dist=[Math]::Sqrt([Math]::Pow($px-$cx,2)+[Math]::Pow($py-$cy,2))
                if ($dist -le 12 -and ($cx -eq $r.x -or $cx -eq $r.x+$r.w -or $cy -eq $r.y -or $cy -eq $r.y+$r.h)) {
                    $candidates += [pscustomobject]@{shape=$r; dist=$dist; cx=$cx; cy=$cy}
                }
            }
            $hit=@($candidates | Sort-Object dist | Select-Object -First 1)
            if ($hit.Count -ne 1) { throw ('Unattached '+$side+' on '+$page.name+' '+$c.id) }
            $hit=$hit[0]; $r=$hit.shape
            $c.SetAttribute($side,$r.id)
            $prefix=if ($side -eq 'source') { 'exit' } else { 'entry' }
            $style += $prefix+'X='+(($hit.cx-$r.x)/$r.w).ToString([Globalization.CultureInfo]::InvariantCulture)+';'+$prefix+'Y='+(($hit.cy-$r.y)/$r.h).ToString([Globalization.CultureInfo]::InvariantCulture)+';'+$prefix+'Dx=0;'+$prefix+'Dy=0;'
            $wired++
        }
        $c.SetAttribute('style',$style)
    }
    foreach ($c in $all) {
        if ($c.vertex -ne '1') { continue }
        $x=[double]$c.mxGeometry.x; $y=[double]$c.mxGeometry.y; $parent=[string]$c.parent; $depth=0
        while ($parent -ne '1') {
            if (++$depth -gt 10) { throw 'Invalid nesting' }
            $pc=$bounds[$parent].cell
            $x += [double]$pc.mxGeometry.x; $y += [double]$pc.mxGeometry.y
            $parent=[string]$pc.parent
        }
        if ($x -ne $bounds[$c.id].x -or $y -ne $bounds[$c.id].y) { throw 'Layout changed during grouping' }
    }
    Write-Output ($page.name+': labels grouped; '+($wired/2)+' native connectors attached; absolute layout preserved.')
}
$settings=[System.Xml.XmlWriterSettings]::new()
$settings.Indent=$true; $settings.Encoding=[System.Text.UTF8Encoding]::new($false)
$writer=[System.Xml.XmlWriter]::Create($path,$settings)
$doc.Save($writer); $writer.Close()
Write-Output 'PASS: final draw.io XML is valid, grouped and connected.'
