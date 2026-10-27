$ErrorActionPreference = 'Stop'
$root = 'C:\Users\HP\projects\az41'
$out = Join-Path $root 'workflow-diagram'
New-Item -ItemType Directory -Force -Path $out | Out-Null
$utf8 = [System.Text.UTF8Encoding]::new($false)
$script:pages = [System.Collections.Generic.List[string]]::new()
function Esc([string]$s) { [System.Security.SecurityElement]::Escape($s) }
function Begin-Page($name, $height) {
    $script:pageName = $name; $script:pageHeight = $height; $script:id = 1
    $script:cells = [System.Collections.Generic.List[string]]::new()
    $script:svg = [System.Collections.Generic.List[string]]::new()
    $script:svg.Add('<svg xmlns="http://www.w3.org/2000/svg" width="1600" height="' + $height + '" viewBox="0 0 1600 ' + $height + '"><defs><marker id="arrow" markerWidth="10" markerHeight="10" refX="8" refY="4" orient="auto" markerUnits="userSpaceOnUse"><path d="M0,0 L8,4 L0,8 Z" fill="#64748B"/></marker></defs><rect width="1600" height="' + $height + '" fill="#F8FAFC"/>')
    Box 0 0 1600 $height '#F8FAFC' '#F8FAFC' 0
}
function Box($x,$y,$w,$h,$fill='#FFFFFF',$stroke='#CBD5E1',$radius=14) {
    $script:id++; $id = 'n' + $script:id
    $rounded = if ($radius -gt 0) { 1 } else { 0 }
    $style = "rounded=$rounded;arcSize=8;whiteSpace=wrap;html=0;fillColor=$fill;strokeColor=$stroke;strokeWidth=1.5;shadow=0;"
    $script:cells.Add('<mxCell id="'+$id+'" value="" style="'+$style+'" vertex="1" parent="1"><mxGeometry x="'+$x+'" y="'+$y+'" width="'+$w+'" height="'+$h+'" as="geometry"/></mxCell>')
    $script:svg.Add('<rect x="'+$x+'" y="'+$y+'" width="'+$w+'" height="'+$h+'" rx="'+$radius+'" fill="'+$fill+'" stroke="'+$stroke+'" stroke-width="1.5"/>')
}
function Txt($x,$y,$w,[string[]]$lines,$size=18,$color='#334155',$bold=$false,$font='Arial',$gap=0) {
    if ($gap -eq 0) { $gap = [Math]::Ceiling($size * 1.45) }
    $weight = if ($bold) { 'bold' } else { 'normal' }
    $fs = if ($bold) { 1 } else { 0 }
    foreach ($line in $lines) {
        $script:id++; $id='n'+$script:id; $v=Esc $line
        $style="text;html=0;whiteSpace=nowrap;overflow=visible;align=left;verticalAlign=top;spacing=0;fontFamily=$font;fontSize=$size;fontColor=$color;fontStyle=$fs;strokeColor=none;fillColor=none;"
        $script:cells.Add('<mxCell id="'+$id+'" value="'+$v+'" style="'+$style+'" vertex="1" parent="1"><mxGeometry x="'+$x+'" y="'+$y+'" width="'+$w+'" height="'+$gap+'" as="geometry"/></mxCell>')
        $script:svg.Add('<text x="'+$x+'" y="'+($y+$size)+'" font-family="'+$font+'" font-size="'+$size+'" font-weight="'+$weight+'" fill="'+$color+'">'+$v+'</text>')
        $y += $gap
    }
}
function Arrow($x1,$y1,$x2,$y2) {
    $script:id++; $id='n'+$script:id
    $script:cells.Add('<mxCell id="'+$id+'" value="" style="edgeStyle=orthogonalEdgeStyle;rounded=1;html=0;endArrow=block;endFill=1;strokeColor=#64748B;strokeWidth=2;" edge="1" parent="1"><mxGeometry relative="1" as="geometry"><mxPoint x="'+$x1+'" y="'+$y1+'" as="sourcePoint"/><mxPoint x="'+$x2+'" y="'+$y2+'" as="targetPoint"/></mxGeometry></mxCell>')
    $script:svg.Add('<path d="M'+$x1+','+$y1+' L'+$x2+','+$y2+'" fill="none" stroke="#64748B" stroke-width="2" marker-end="url(#arrow)"/>')
}
function Stage($n,$title,$y,$h,$color='#1D4ED8',$fill='#EFF6FF') {
    Box 500 $y 600 $h $fill '#BFDBFE'
    Box 522 ($y+22) 45 40 $color $color 8
    Txt 534 ($y+29) 30 @($n) 22 '#FFFFFF' $true
    Txt 585 ($y+29) 490 @($title) 24 '#0F172A' $true
}
function Card($x,$y,$h,$label,$lines,$fill='#FFFFFF',$stroke='#CBD5E1') {
    $h = [Math]::Max($h, 56 + $lines.Count * 27 + 18)
    Box $x $y 390 $h $fill $stroke
    Txt ($x+22) ($y+20) 346 @($label) 15 '#64748B' $true
    Txt ($x+22) ($y+56) 346 $lines 18
}
function End-Page($slug) {
    $script:svg.Add('</svg>')
    [System.IO.File]::WriteAllText((Join-Path $out ($slug+'.svg')), ($script:svg -join "`n"), $utf8)
    $script:pages.Add('<diagram id="'+$slug+'" name="'+(Esc $script:pageName)+'"><mxGraphModel dx="1600" dy="'+$script:pageHeight+'" grid="1" gridSize="10" guides="1" tooltips="1" connect="1" arrows="1" fold="1" page="1" pageScale="1" pageWidth="1600" pageHeight="'+$script:pageHeight+'" background="#F8FAFC" math="0" shadow="0"><root><mxCell id="0"/><mxCell id="1" parent="0"/>'+($script:cells -join "`n")+'</root></mxGraphModel></diagram>')
}

Begin-Page '01 - Complete AZ41 workflow' 2420
Txt 60 42 1200 @('AZ41 | From crystal files to precipitates') 38 '#0F172A' $true
Txt 60 100 1450 @('Five preparation stages, with file provenance and the final CFG as the endpoint.') 21 '#475569'
Box 60 151 17 17 '#EFF6FF' '#BFDBFE' 4
Txt 88 148 330 @('Blue: processing step') 16
Box 385 151 17 17 '#FFFFFF' '#CBD5E1' 4
Txt 413 148 330 @('White: inputs / supporting files') 16
Box 790 151 17 17 '#ECFDF5' '#6EE7B7' 4
Txt 818 148 340 @('Green: output / retained artifact') 16
Txt 60 202 390 @('INPUTS / REQUIREMENTS') 15 '#64748B' $true
Txt 500 202 600 @('WORKFLOW / WHAT HAPPENS') 15 '#64748B' $true
Txt 1150 202 390 @('OUTPUTS / MODEL DETAILS') 15 '#64748B' $true

Card 60 240 200 'SOURCE STRUCTURES' @('Crystallographic records for:','hcp Mg (matrix phase)','Mg17Al12 (precipitate phase)','Record IDs: 9012001, 1576218')
Stage '1' 'Download the crystal structures' 240 220
Txt 524 324 552 @('Obtain the CIF for each phase.','Mg supplies the matrix crystal structure;','Mg17Al12 supplies the beta-phase unit cell.','Retain both files for their later branches.') 20
Card 1150 240 220 'DOWNLOADED CIF FILES' @('9012001-Mghcp.cif','1576218-Mg17Al12.cif','','The beta CIF is read again in step 5.') '#ECFDF5' '#6EE7B7'
Arrow 450 350 492 350; Arrow 1108 350 1142 350; Arrow 800 460 800 510

Card 60 520 200 'SIMULATION DESIGN' @('Cubic box: 201 x 201 x 201 Å','Equivalent length: 20.1 nm per side','Number of grains: 20','Random grain positions/orientations')
Stage '2' 'Write the box parameter file' 520 210
Txt 524 598 550 @('Define the box and request 20 random grains.') 20
Box 524 640 552 65 '#FFFFFF' '#BFDBFE' 8
Txt 542 649 512 @('box 201 201 201','random 20') 19 '#0F172A' $false 'Courier New' 24
Card 1150 520 210 'SAVED PARAMETER FILE' @('param.txt.txt','','Called param.txt in the workflow;','the actual saved filename and','terminal command use param.txt.txt.') '#ECFDF5' '#6EE7B7'
Arrow 450 625 492 625; Arrow 1108 625 1142 625; Arrow 800 730 800 780

Card 60 790 350 'ATOMSK INPUT FILES' @('9012001-Mghcp.lmp','param.txt.txt','','Prerequisite: convert the Mg CIF','to the LAMMPS unit-cell file above.','The LMP exists in this project;','its conversion command is not','recorded in the workflow notes.','','The beta-phase LMP is not used','by the precipitate insertion script.')
Stage '3' 'Build the pure-Mg polycrystal' 790 370
Txt 524 870 552 @('Atomsk fills 20 Voronoi grains with hcp Mg,','assigns grain orientations, and wraps atoms','into the periodic simulation box.') 20
Box 524 973 552 115 '#FFFFFF' '#BFDBFE' 8
Txt 542 988 516 @('atomsk --polycrystal','"9012001-Mghcp.lmp" param.txt.txt','az41poly.lmp lmp cfg -wrap') 18 '#0F172A' $false 'Courier New' 29
Txt 524 1112 552 @('349,469 atoms | Mg only | no alloying yet') 20 '#1D4ED8' $true
Card 1150 790 370 'GENERATED FILES' @('az41poly.cfg  →  step 4','az41poly.lmp','az41poly_param.txt  →  step 5','','Grain geometry / statistics:','az41poly_nodes.xsf','az41poly_grains-com.xsf','az41poly_id-size.txt','az41poly_size-dist.txt','','The generated parameter file stores','the actual grain nodes and rotations.') '#ECFDF5' '#6EE7B7'
Arrow 450 975 492 975; Arrow 1108 975 1142 975; Arrow 800 1160 800 1210

Card 60 1220 260 'ALLOYING INPUT' @('az41poly.cfg  (from step 3)','','Random substitution in the CFG:','13,055 Mg atoms → Al','1,496 remaining Mg atoms → Zn','','Keep the box, grain geometry','and grainID auxiliary information.')
Stage '4' 'Create the AZ41 solid solution' 1220 350
Txt 524 1300 552 @('Replace selected Mg atoms with Al and Zn.','This creates an alloyed matrix before any','Mg17Al12 precipitates are inserted.') 20
Box 524 1400 552 130 '#FFFFFF' '#BFDBFE' 8
Txt 540 1414 520 @('atomsk az41poly.cfg','-select random 13055 Mg -substitute Mg Al','-select random 1496 Mg -substitute Mg Zn','az41poly_alloy2 lmp cfg') 17 '#0F172A' $false 'Courier New' 26
Card 1150 1220 350 'ALLOYED OUTPUT FILES' @('az41poly_alloy2.cfg  →  step 5','','349,469 atoms; Mg-Al-Zn matrix.','This CFG carries the alloyed structure.','','Companion: az41poly_alloy2.lmp','The notes report incorrect species','in that LMP and an OVITO conversion','from the CFG to repair the data file.','','Precipitate insertion uses the CFG.') '#ECFDF5' '#6EE7B7'
Arrow 450 1395 492 1395; Arrow 1108 1395 1142 1395; Arrow 800 1570 800 1620

Card 60 1630 480 'SCRIPT INPUTS + DEPENDENCIES' @('az41poly_alloy2.cfg  (step 4)','az41poly_param.txt  (step 3)','1576218-Mg17Al12.cif  (step 1)','','Helper modules:','cfg_utils.py  — CFG read/write','cif_utils.py  — CIF expansion','orientation.py  — grain / beta rotation','','Runtime: Python, NumPy, SciPy.','','Set CFG_PATH, NODE_PATH, CIF_PATH','and OUT_PATH for the working machine.','The supplied script contains paths','from its original execution environment.')
Stage '5' 'Insert the Mg17Al12 precipitates' 1630 480 '#6D28D9' '#F5F3FF'
Txt 524 1709 552 @('Run insert_precipitates.py with the three','data files and helper modules at left.') 20
Box 524 1780 552 52 '#FFFFFF' '#C4B5FD' 8
Txt 542 1794 516 @('python insert_precipitates.py') 18 '#0F172A' $false 'Courier New'
Txt 524 1857 552 @('1. Read matrix, grain orientations and beta CIF.','2. Detect grain boundaries; select spaced sites.','3. Build cubes; align to the host-grain Burgers OR.','4. Replace matrix regions; wrap and clean overlaps.','5. Reduce excess Al by nearby matrix substitution.','6. Write the combined extended CFG.') 19 '#334155' $false 'Arial' 32
Txt 524 2070 552 @('See page 2 for the internal data flow.') 18 '#6D28D9' $true
Card 1150 1630 480 'INSERTION SETTINGS / INTERPRETATION' @('Cube edge: 35 Å (3.5 nm, scaled)','Target volume fraction: 10%','GB-neighbor cutoff: 3.6 Å','Matrix-removal buffer: 2.5 Å','Final overlap cutoff: 1.6 Å','Minimum center spacing: >56 Å','Random seed: 7','','Geometric construction of precipitates;','the target fraction is not a guarantee.','','Al compensation is limited by available','matrix Al. It does not guarantee exact','bulk AZ41 composition after insertion.','','OR = orientation relationship.','GB = grain boundary.')
Arrow 450 1850 492 1850; Arrow 1142 1850 1108 1850; Arrow 800 2110 800 2170
Box 370 2180 860 175 '#065F46' '#065F46' 18
Txt 401 2201 798 @('FINAL OUTPUT  /  WORKFLOW ENDS HERE') 16 '#A7F3D0' $true
Txt 401 2238 798 @('az41poly_with_precipitates.cfg') 29 '#FFFFFF' $true
Txt 401 2283 798 @('Extended CFG: matrix + beta precipitates, species, coordinates and grain IDs.','Existing example: 339,897 atoms in the 201 Å cubic box.') 19 '#ECFDF5' $false 'Arial' 28
Txt 60 2370 1480 @('Commands wrap for display; enter each as one line. Sources: project notes, parameters, CFG headers and driver script.  |  01 / 02') 15 '#64748B'
End-Page '01-complete-workflow'

Begin-Page '02 - Inside precipitate insertion' 2390
Txt 60 42 1460 @('Step 5 | Inside precipitate insertion') 38 '#0F172A' $true
Txt 60 101 1450 @('How the alloyed polycrystal, grain orientations and beta crystal structure become one extended CFG.') 21 '#475569'
Box 60 170 470 260 '#FFFFFF' '#CBD5E1'
Txt 82 192 426 @('MATRIX INPUT') 15 '#64748B' $true
Txt 82 230 426 @('az41poly_alloy2.cfg') 22 '#0F172A' $true
Txt 82 277 426 @('cfg_utils.py reads the box, atom species,','Cartesian positions and grain IDs.','','Inherited from the alloying stage.','The grainID field links atoms to host grains.') 19
Box 565 170 470 260 '#FFFFFF' '#CBD5E1'
Txt 587 192 426 @('GRAIN GEOMETRY INPUT') 15 '#64748B' $true
Txt 587 230 426 @('az41poly_param.txt') 22 '#0F172A' $true
Txt 587 277 426 @('orientation.py reads grain nodes and angles.','It constructs each host-grain rotation.','','Use the generated file with explicit nodes,','not the initial random-grain request.') 19
Box 1070 170 470 260 '#FFFFFF' '#CBD5E1'
Txt 1092 192 426 @('PRECIPITATE CRYSTAL INPUT') 15 '#64748B' $true
Txt 1092 230 426 @('1576218-Mg17Al12.cif') 22 '#0F172A' $true
Txt 1092 277 426 @('cif_utils.py expands the symmetry sites','into the beta conventional unit cell.','','58 atoms: Mg34Al24; cubic lattice','parameter a = 10.5438 Å.') 19
Arrow 295 430 295 450; Arrow 800 430 800 450; Arrow 1305 430 1305 450
Box 60 460 1480 65 '#6D28D9' '#6D28D9' 12
Txt 82 478 1420 @('insert_precipitates.py   |   Python + NumPy + SciPy   |   input paths and OUT_PATH configured before execution') 21 '#FFFFFF' $true
Arrow 620 525 620 565

function Detail($code,$title,$y,$lines) {
    Box 60 $y 1020 170 '#F5F3FF' '#DDD6FE'
    Box 82 ($y+22) 58 42 '#6D28D9' '#6D28D9' 8
    Txt 94 ($y+30) 40 @($code) 20 '#FFFFFF' $true
    Txt 158 ($y+28) 890 @($title) 24 '#0F172A' $true
    Txt 84 ($y+82) 970 $lines 20 '#334155' $false 'Arial' 29
}
Detail '5A' 'Load the matrix, crystallography and rotations' 575 @('Read the three inputs. Build the beta cell and the Burgers orientation rotation R_OR.','Internal result: matrix arrays, a grain-rotation lookup and a reusable beta unit cell.')
Card 1150 575 170 'ORIENTATION CONVENTION' @('R_grain = Rz × Ry × Rx','R_lab = R_grain × R_OR','The helper assumes this rotation order.','OR aligns each cube to its host grain.')
Arrow 570 745 570 775

Detail '5B' 'Detect atoms at grain boundaries' 785 @('Use a periodic cKDTree to find atom pairs within 3.6 Å.','Flag atoms in pairs whose grain IDs differ. Internal result: GB positions and host IDs.')
Card 1150 785 170 'WHY GRAIN IDS MATTER' @('Different neighboring grain IDs','identify boundary atoms directly.','The script does not infer grains','from a later structural analysis.')
Arrow 570 955 570 985

Detail '5C' 'Select well-separated nucleation sites' 995 @('Shuffle the GB candidates using seed 7; accept centers more than 56 Å apart.','Target count = round(0.10 × box volume / 35³) = 19; fewer sites may be accepted.')
Card 1150 995 170 'INTERNAL OUTPUT' @('Chosen centers + host-grain IDs.','Periodic minimum-image distances','keep selected centers apart.','10% is a nominal geometric target.')
Arrow 570 1165 570 1195

Detail '5D' 'Build and orient each beta precipitate' 1205 @('Repeat the Mg17Al12 unit cell and crop a 35 Å cube in its own crystal axes.','Rotate with R_lab and translate to the selected GB center. Result: oriented beta atoms.')
Card 1150 1205 170 'MORPHOLOGY / SCALE' @('Block-shaped beta precipitates.','35 Å = 3.5 nm cube edge.','This is the script''s scaled model size,','not a measured experimental size.')
Arrow 570 1375 570 1405

Detail '5E' 'Replace matrix regions and merge the atom sets' 1415 @('Remove matrix atoms inside each rotated cube plus a 2.5 Å buffer.','Append the beta atoms; assign precipitate grain IDs 101, 102, … and merge the arrays.')
Card 1150 1415 170 'INTERNAL OUTPUT' @('Combined species and coordinates.','Matrix grain IDs are retained;','new IDs distinguish precipitates.','Atom count changes during insertion.')
Arrow 570 1585 570 1615

Detail '5F' 'Wrap into the box and clean close contacts' 1625 @('Wrap fractional coordinates into [0, 1). Search periodic pairs closer than 1.6 Å.','Remove conflicting matrix atoms, favoring beta atoms; beta–beta pairs are left intact.')
Card 1150 1625 170 'PERIODIC CLEANUP' @('The merged structure stays inside','the original periodic box.','Cleanup removes close matrix contacts;','it is a geometric operation.')
Arrow 570 1795 570 1825

Detail '5G' 'Apply the local Al-depletion approximation' 1835 @('Compare final Al count with the input Al count. Rank matrix Al by proximity to precipitates.','Convert nearby excess matrix Al back to Mg, limited by the number of matrix Al atoms.')
Card 1150 1835 170 'COMPOSITION LIMIT' @('The correction targets the initial','Al atom count. The total atom count','changes, and matrix Al can run out;','exact composition is not guaranteed.')
Arrow 570 2005 570 2050
Box 60 2060 1480 210 '#065F46' '#065F46' 18
Txt 88 2085 1400 @('LAST OPERATION  /  WRITE THE FINAL EXTENDED CFG') 16 '#A7F3D0' $true
Txt 88 2126 1400 @('az41poly_with_precipitates.cfg') 32 '#FFFFFF' $true
Txt 88 2180 1400 @('cfg_utils.write_extended_cfg writes the box, chemical species, wrapped coordinates and grain IDs.','The existing project example contains 339,897 atoms. This file is the endpoint of the requested workflow.') 21 '#ECFDF5' $false 'Arial' 33
Txt 60 2315 1480 @('File inputs are shown by basename. The driver and helper modules are in the project''s files from claude folder.  |  02 / 02') 16 '#64748B'
End-Page '02-precipitate-insertion'

$xml = '<?xml version="1.0" encoding="UTF-8"?>' + "`n" + '<mxfile host="app.diagrams.net" agent="AZ41 workflow documentation" version="24.7.17" type="device">' + "`n" + ($script:pages -join "`n") + "`n</mxfile>"
[System.IO.File]::WriteAllText((Join-Path $out 'AZ41_workflow.xml'), $xml, $utf8)
[xml]$check = $xml
foreach ($page in $check.mxfile.diagram) {
    $ids = @($page.mxGraphModel.root.mxCell | ForEach-Object { $_.id })
    if (($ids | Select-Object -Unique).Count -ne $ids.Count) { throw 'Duplicate cell IDs' }
    Write-Output ($page.name + ': ' + $ids.Count + ' editable cells')
}
Write-Output ('Created ' + (Join-Path $out 'AZ41_workflow.xml'))
