#once

; ============================================================
; BUILD CONFIGURATION
;
; BUILD_DEBUG controls the build type:
;   0 = Release: no boot tests, includes TinyPascal (P-Machine + editor + compiler)
;   1 = Debug:   includes boot tests, excludes TinyPascal
;
; The three ROM banks (0x0000-0x5FFF) are always treated as a
; single contiguous 24 KB address space.
; ============================================================

#const BUILD_DEBUG = 0
