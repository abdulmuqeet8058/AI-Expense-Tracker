Add-Type -AssemblyName System.Drawing

$width = 1600
$height = 1000
$outputPath = Join-Path $PSScriptRoot "svm_mobile_activity_diagram.png"
$bitmap = New-Object System.Drawing.Bitmap($width, $height)
$graphics = [System.Drawing.Graphics]::FromImage($bitmap)
$graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
$graphics.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::AntiAliasGridFit

function New-RoundedPath {
    param([float]$X, [float]$Y, [float]$Width, [float]$Height, [float]$Radius)
    $path = New-Object System.Drawing.Drawing2D.GraphicsPath
    $diameter = $Radius * 2
    $path.AddArc($X, $Y, $diameter, $diameter, 180, 90)
    $path.AddArc($X + $Width - $diameter, $Y, $diameter, $diameter, 270, 90)
    $path.AddArc($X + $Width - $diameter, $Y + $Height - $diameter, $diameter, $diameter, 0, 90)
    $path.AddArc($X, $Y + $Height - $diameter, $diameter, $diameter, 90, 90)
    $path.CloseFigure()
    return $path
}

function Fill-RoundedRectangle {
    param($Brush, [float]$X, [float]$Y, [float]$Width, [float]$Height, [float]$Radius)
    $path = New-RoundedPath $X $Y $Width $Height $Radius
    $graphics.FillPath($Brush, $path)
    $path.Dispose()
}

function Draw-RoundedRectangle {
    param($Pen, [float]$X, [float]$Y, [float]$Width, [float]$Height, [float]$Radius)
    $path = New-RoundedPath $X $Y $Width $Height $Radius
    $graphics.DrawPath($Pen, $path)
    $path.Dispose()
}

function Draw-Text {
    param(
        [string]$Text,
        $Font,
        $Brush,
        [float]$X,
        [float]$Y,
        [float]$Width,
        [float]$Height,
        [string]$Alignment = "Near",
        [string]$LineAlignment = "Near"
    )
    $format = New-Object System.Drawing.StringFormat
    $format.Alignment = [System.Drawing.StringAlignment]::$Alignment
    $format.LineAlignment = [System.Drawing.StringAlignment]::$LineAlignment
    $format.Trimming = [System.Drawing.StringTrimming]::EllipsisWord
    $graphics.DrawString($Text, $Font, $Brush, [System.Drawing.RectangleF]::new($X, $Y, $Width, $Height), $format)
    $format.Dispose()
}

function Draw-Arrow {
    param([float]$X1, [float]$Y1, [float]$X2, [float]$Y2, $Pen, $Brush)
    $graphics.DrawLine($Pen, $X1, $Y1, $X2, $Y2)
    $points = [System.Drawing.PointF[]]@(
        [System.Drawing.PointF]::new($X2, $Y2),
        [System.Drawing.PointF]::new($X2 - 13, $Y2 - 8),
        [System.Drawing.PointF]::new($X2 - 13, $Y2 + 8)
    )
    $graphics.FillPolygon($Brush, $points)
}

$navy = [System.Drawing.ColorTranslator]::FromHtml("#0B1739")
$blue = [System.Drawing.ColorTranslator]::FromHtml("#2563EB")
$cyan = [System.Drawing.ColorTranslator]::FromHtml("#06B6D4")
$green = [System.Drawing.ColorTranslator]::FromHtml("#10B981")
$orange = [System.Drawing.ColorTranslator]::FromHtml("#F59E0B")
$purple = [System.Drawing.ColorTranslator]::FromHtml("#8B5CF6")
$white = [System.Drawing.Color]::White
$paper = [System.Drawing.ColorTranslator]::FromHtml("#F5F8FF")
$muted = [System.Drawing.ColorTranslator]::FromHtml("#52617A")
$line = [System.Drawing.ColorTranslator]::FromHtml("#D8E2F2")
$softBlue = [System.Drawing.ColorTranslator]::FromHtml("#E8F0FF")
$softGreen = [System.Drawing.ColorTranslator]::FromHtml("#E7F8F2")
$softOrange = [System.Drawing.ColorTranslator]::FromHtml("#FFF3DB")
$softPurple = [System.Drawing.ColorTranslator]::FromHtml("#F1EBFF")

$backgroundBrush = New-Object System.Drawing.SolidBrush($paper)
$navyBrush = New-Object System.Drawing.SolidBrush($navy)
$whiteBrush = New-Object System.Drawing.SolidBrush($white)
$mutedBrush = New-Object System.Drawing.SolidBrush($muted)
$blueBrush = New-Object System.Drawing.SolidBrush($blue)
$cyanBrush = New-Object System.Drawing.SolidBrush($cyan)
$greenBrush = New-Object System.Drawing.SolidBrush($green)
$orangeBrush = New-Object System.Drawing.SolidBrush($orange)
$purpleBrush = New-Object System.Drawing.SolidBrush($purple)
$softBlueBrush = New-Object System.Drawing.SolidBrush($softBlue)
$softGreenBrush = New-Object System.Drawing.SolidBrush($softGreen)
$softOrangeBrush = New-Object System.Drawing.SolidBrush($softOrange)
$softPurpleBrush = New-Object System.Drawing.SolidBrush($softPurple)

$titleFont = New-Object System.Drawing.Font("Segoe UI", 34, [System.Drawing.FontStyle]::Bold)
$subtitleFont = New-Object System.Drawing.Font("Segoe UI", 16, [System.Drawing.FontStyle]::Regular)
$badgeFont = New-Object System.Drawing.Font("Segoe UI", 12, [System.Drawing.FontStyle]::Bold)
$stepFont = New-Object System.Drawing.Font("Segoe UI", 14, [System.Drawing.FontStyle]::Bold)
$cardTitleFont = New-Object System.Drawing.Font("Segoe UI", 15, [System.Drawing.FontStyle]::Bold)
$cardBodyFont = New-Object System.Drawing.Font("Segoe UI", 13, [System.Drawing.FontStyle]::Regular)
$calloutFont = New-Object System.Drawing.Font("Segoe UI", 20, [System.Drawing.FontStyle]::Bold)
$smallFont = New-Object System.Drawing.Font("Segoe UI", 11, [System.Drawing.FontStyle]::Regular)
$labelFont = New-Object System.Drawing.Font("Segoe UI", 11, [System.Drawing.FontStyle]::Bold)

$graphics.FillRectangle($backgroundBrush, 0, 0, $width, $height)
Fill-RoundedRectangle $navyBrush 70 45 250 38 19
Draw-Text "MOBILE ML EXPLAINER" $badgeFont $whiteBrush 70 45 250 38 "Center" "Center"
Draw-Text "HOW A PHONE RECOGNIZES YOUR ACTIVITY" $titleFont $navyBrush 70 100 1460 65
Draw-Text "Support Vector Machine (SVM) | From raw accelerometer signals to an activity prediction" $subtitleFont $mutedBrush 70 169 1460 42

$cardXs = @(70, 445, 820, 1195)
$cardBrushes = @($softBlueBrush, $softGreenBrush, $softOrangeBrush, $softPurpleBrush)
$accentBrushes = @($blueBrush, $greenBrush, $orangeBrush, $purpleBrush)
$titles = @("PHONE SENSORS", "FEATURE ENGINEERING", "SCALE + CLASSIFY", "ACTIVITY OUTPUT")
$bodies = @(
    "Accelerometer: X, Y, Z`n50 samples per second`n2.5-second motion window",
    "Mean | standard deviation`nEnergy | peak-to-peak`nDominant motion frequency",
    "StandardScaler`nRBF-kernel SVM`nMaximum-margin boundary",
    "STATIONARY | WALKING | RUNNING`nPredicted activity`n+ calibrated probabilities"
)

for ($i = 0; $i -lt 4; $i++) {
    $x = $cardXs[$i]
    Fill-RoundedRectangle $cardBrushes[$i] $x 240 300 310 24
    $borderPen = New-Object System.Drawing.Pen($line, 2)
    Draw-RoundedRectangle $borderPen $x 240 300 310 24
    $borderPen.Dispose()
    $graphics.FillEllipse($accentBrushes[$i], $x + 24, 264, 46, 46)
    Draw-Text ([string]($i + 1)) $stepFont $whiteBrush ($x + 24) 264 46 46 "Center" "Center"
    Draw-Text $titles[$i] $cardTitleFont $navyBrush ($x + 24) 330 252 38
    Draw-Text $bodies[$i] $cardBodyFont $mutedBrush ($x + 24) 380 252 128
}

$arrowPen = New-Object System.Drawing.Pen($blue, 4)
for ($i = 0; $i -lt 3; $i++) {
    Draw-Arrow ($cardXs[$i] + 310) 395 ($cardXs[$i + 1] - 10) 395 $arrowPen $blueBrush
}
$arrowPen.Dispose()

Fill-RoundedRectangle $navyBrush 70 610 500 300 24
Draw-Text "THE IMPORTANT IDEA" $labelFont $cyanBrush 102 645 430 30
Draw-Text "The model never sees`n'walking' directly." $calloutFont $whiteBrush 102 683 430 78
Draw-Text "It learns patterns from labelled sensor windows. The support vectors are the closest examples to the boundary - and the points that matter most." $cardBodyFont $whiteBrush 102 775 415 105

Fill-RoundedRectangle $whiteBrush 610 610 920 300 24
$plotBorder = New-Object System.Drawing.Pen($line, 2)
Draw-RoundedRectangle $plotBorder 610 610 920 300 24
$plotBorder.Dispose()
Draw-Text "SVM DECISION SPACE (SIMPLIFIED)" $labelFont $navyBrush 642 636 420 28

$axisPen = New-Object System.Drawing.Pen($muted, 2)
$graphics.DrawLine($axisPen, 690, 850, 1465, 850)
$graphics.DrawLine($axisPen, 690, 850, 690, 685)
Draw-Text "motion energy  ->" $smallFont $mutedBrush 1250 857 220 25
Draw-Text "dominant frequency" $smallFont $mutedBrush 620 655 185 25
$axisPen.Dispose()

$boundaryPen1 = New-Object System.Drawing.Pen($green, 3)
$boundaryPen1.DashStyle = [System.Drawing.Drawing2D.DashStyle]::Dash
$boundaryPen2 = New-Object System.Drawing.Pen($orange, 3)
$boundaryPen2.DashStyle = [System.Drawing.Drawing2D.DashStyle]::Dash
$graphics.DrawBezier($boundaryPen1, 895, 845, 860, 790, 920, 735, 950, 690)
$graphics.DrawBezier($boundaryPen2, 1190, 845, 1140, 800, 1195, 735, 1240, 685)
$boundaryPen1.Dispose()
$boundaryPen2.Dispose()

$clusters = @(
    @{ X = 770; Y = 815; Brush = $blueBrush; Label = "STATIONARY" },
    @{ X = 1040; Y = 760; Brush = $greenBrush; Label = "WALKING" },
    @{ X = 1330; Y = 710; Brush = $orangeBrush; Label = "RUNNING" }
)
$offsets = @(@(-48, 15), @(-26, -14), @(0, 11), @(28, -8), @(45, 18), @(12, -30), @(-8, 34))
foreach ($cluster in $clusters) {
    foreach ($offset in $offsets) {
        $px = $cluster.X + $offset[0]
        $py = $cluster.Y + $offset[1]
        $graphics.FillEllipse($cluster.Brush, $px - 7, $py - 7, 14, 14)
    }
    Draw-Text $cluster.Label $labelFont $navyBrush ($cluster.X - 68) ($cluster.Y - 68) 136 25 "Center"
}

$supportPen = New-Object System.Drawing.Pen($purple, 4)
$graphics.DrawEllipse($supportPen, 853, 806, 28, 28)
$graphics.DrawEllipse($supportPen, 1160, 786, 28, 28)
$supportPen.Dispose()
Draw-Text "circled points = support vectors" $smallFont $purpleBrush 995 872 250 24 "Center"

$bitmap.Save($outputPath, [System.Drawing.Imaging.ImageFormat]::Png)

$graphics.Dispose()
$bitmap.Dispose()
$backgroundBrush.Dispose()
$navyBrush.Dispose()
$whiteBrush.Dispose()
$mutedBrush.Dispose()
$blueBrush.Dispose()
$cyanBrush.Dispose()
$greenBrush.Dispose()
$orangeBrush.Dispose()
$purpleBrush.Dispose()
$softBlueBrush.Dispose()
$softGreenBrush.Dispose()
$softOrangeBrush.Dispose()
$softPurpleBrush.Dispose()
$titleFont.Dispose()
$subtitleFont.Dispose()
$badgeFont.Dispose()
$stepFont.Dispose()
$cardTitleFont.Dispose()
$cardBodyFont.Dispose()
$calloutFont.Dispose()
$smallFont.Dispose()
$labelFont.Dispose()

Write-Output "Saved $outputPath"
