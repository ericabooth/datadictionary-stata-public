*! version 1.0.1  21aug2026  Eric Booth
*! _dd_open -- open one of the files datadictionary just wrote, using the
*! operating system's own handler.  Called from the click-to-run links the
*! command prints when it finishes.
*!
*! Why this exists rather than SMCL's {browse}: {browse} hands its target to
*! the platform's URL machinery, and on macOS a local path passed that way can
*! throw an uncaught exception inside NSURLComponents and abort Stata (seen in
*! StataNow 19.5 on macOS 26.5, crash report ending in
*! -[_NSURLComponentsBridge setScheme:]).  A browser is also the wrong handler
*! for a .xlsx, a .dta, or a folder.  {stata ...} links run a Stata command,
*! which never reaches that code path, and the OS opener picks the right
*! application for each file type.
*!
*! The path arrives through a global rather than as a literal argument so the
*! SMCL directive stays free of quotes, spaces, and colons: a Windows path
*! begins "C:", and a colon inside {stata ...} separates command from label.

program define _dd_open
    version 16.0
    args n
    if "`n'" == "" local n 1
    local f `"${DD_OPEN`n'}"'
    if `"`f'"' == "" {
        di as err "datadictionary: nothing to open"
        exit 198
    }
    capture confirm file `"`f'"'
    if _rc {
        * a folder, or something already moved
        mata: st_local("isdir", strofreal(direxists(st_local("f"))))
        if "`isdir'" != "1" {
            di as err `"datadictionary: `f' not found"'
            exit 601
        }
    }
    local q = char(34)
    if "`c(os)'" == "MacOSX" {
        shell open `q'`f'`q'
    }
    else if "`c(os)'" == "Windows" {
        winexec cmd /c start "" `q'`f'`q'
    }
    else {
        shell xdg-open `q'`f'`q' &
    }
end
