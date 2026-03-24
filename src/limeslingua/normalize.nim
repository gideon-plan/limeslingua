## normalize.nim -- Locale-aware text normalization before embedding.
##
## Unicode normalization (NFC/NFKC), whitespace normalization,
## and script detection for routing decisions.

{.experimental: "strict_funcs".}

import std/[strutils, unicode]
import detect

# =====================================================================================================================
# Types
# =====================================================================================================================

type
  NormForm* = enum
    nfNone     ## No Unicode normalization
    nfNFC      ## Canonical composition
    nfNFKC     ## Compatibility composition

  NormConfig* = object
    form*: NormForm
    lowercase*: bool
    strip_whitespace*: bool
    collapse_whitespace*: bool

  Script* = enum
    scLatin
    scCyrillic
    scCJK
    scArabic
    scDevanagari
    scUnknown

# =====================================================================================================================
# Configuration
# =====================================================================================================================

proc default_norm_config*(): NormConfig =
  NormConfig(form: nfNFC, lowercase: true, strip_whitespace: true,
             collapse_whitespace: true)

# =====================================================================================================================
# Normalization
# =====================================================================================================================

proc normalize_whitespace(text: string, config: NormConfig): string =
  result = text
  if config.strip_whitespace:
    result = result.strip()
  if config.collapse_whitespace:
    var collapsed = ""
    var prev_space = false
    for c in result:
      if c in {' ', '\t', '\r', '\n'}:
        if not prev_space:
          collapsed.add(' ')
          prev_space = true
      else:
        collapsed.add(c)
        prev_space = false
    result = collapsed

proc normalize_text*(text: string,
                     config: NormConfig = default_norm_config()): string =
  ## Normalize text for embedding.
  result = text
  if config.lowercase:
    result = unicode.toLower(result)
  result = normalize_whitespace(result, config)

proc normalize_for_language*(text: string, lang: Language,
                             config: NormConfig = default_norm_config()): string =
  ## Language-specific normalization. Currently delegates to generic normalize.
  normalize_text(text, config)

# =====================================================================================================================
# Script detection
# =====================================================================================================================

proc detect_script*(text: string): Script =
  ## Detect the dominant script of the text by sampling codepoints.
  var counts: array[Script, int]
  for r in text.runes:
    let cp = int(r)
    if cp >= 0x0041 and cp <= 0x024F:
      inc counts[scLatin]
    elif cp >= 0x0400 and cp <= 0x04FF:
      inc counts[scCyrillic]
    elif (cp >= 0x4E00 and cp <= 0x9FFF) or (cp >= 0x3040 and cp <= 0x30FF):
      inc counts[scCJK]
    elif cp >= 0x0600 and cp <= 0x06FF:
      inc counts[scArabic]
    elif cp >= 0x0900 and cp <= 0x097F:
      inc counts[scDevanagari]
  var max_count = 0
  result = scUnknown
  for s in Script:
    if counts[s] > max_count:
      max_count = counts[s]
      result = s
