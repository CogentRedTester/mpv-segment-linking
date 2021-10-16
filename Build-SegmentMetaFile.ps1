# This script is for creating segment files for mpv-segment-linking
# Available at: https://github.com/CogentRedTester/mpv-segment-linking
# Segment File version: v0.1

$output_file = ".segment-linking"
$files = @()

$flag = $false

foreach ($arg in $args) {
    if ($arg -eq "-o") {
        $flag = $true
        continue
    }

    if ($flag) {
        $output_file = $arg
        continue
    }

    foreach ($item in $args) {
        if ($item.Name) {
            $files += $item.Name
        }
        else {
            $files += $item
        }
    }
}

"# mpv-segment-linking v0.1" > $output_file
"" >> $output_file

foreach ($file in $files) {
    $out = mkvinfo "$file"
    # echo $out
    if ( $LASTEXITCODE -ne 0 ) {
        continue;
    }

    $file >> $output_file


    if ( $UID = ($out | Select-String -Pattern 'Segment UID: ([^\n\r]+)' -CaseSensitive)) {
        "UID="+$UID.Matches.Groups[1] >> $output_file
    }

    if ( $prev = ($out | Select-String -Pattern 'Previous segment UID: ([^\n\r]+)' -CaseSensitive)) {
        "PREV="+$prev.Matches.Groups[1] >> $output_file
    }

    if ( $next = ($out | Select-String -Pattern 'Next segment UID: ([^\n\r]+)' -CaseSensitive)) {
        "NEXT="+$next.Matches.Groups[1] >> $output_file
    }

    "" >> $output_file
}