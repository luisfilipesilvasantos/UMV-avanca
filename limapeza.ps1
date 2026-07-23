Get-ChildItem -Path . -Recurse -Include *.bat, *.cmd, *.ps1, *.txt, *.cpp, *.h |
ForEach-Object {
    (Get-Content $_.FullName) |
    Where-Object {
        $_ -notmatch 'User''s Edge browser tabs metadata'
    } |
    Set-Content $_.FullName
}

