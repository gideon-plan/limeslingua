## detect.nim -- Language detection as pre-processing step for embeddings.
##
## Wraps lingua's language detection to tag text before embedding/routing.

{.experimental: "strict_funcs".}

import lattice

# =====================================================================================================================
# Types
# =====================================================================================================================

type
  Language* = object
    code*: string    ## ISO 639-1 code (e.g. "en", "de", "ja")
    name*: string    ## Full name (e.g. "English", "German", "Japanese")
    confidence*: float64

  DetectFn* = proc(text: string): Result[Language, BridgeError] {.raises: [].}
    ## Function that detects the language of text.
    ## Abstracts over lingua's detection API.

  DetectMultiFn* = proc(text: string, top_k: int): Result[seq[Language], BridgeError] {.raises: [].}
    ## Function that returns top-k language candidates.

# =====================================================================================================================
# Detection
# =====================================================================================================================

proc detect*(text: string, detect_fn: DetectFn): Result[Language, BridgeError] =
  detect_fn(text)

proc detect_multi*(text: string, detect_fn: DetectMultiFn,
                   top_k: int = 3): Result[seq[Language], BridgeError] =
  detect_fn(text, top_k)

proc is_language*(lang: Language, code: string): bool =
  lang.code == code

proc language*(code, name: string, confidence: float64 = 1.0): Language =
  Language(code: code, name: name, confidence: confidence)

# =====================================================================================================================
# Common languages
# =====================================================================================================================

let
  English* = Language(code: "en", name: "English", confidence: 1.0)
  German* = Language(code: "de", name: "German", confidence: 1.0)
  French* = Language(code: "fr", name: "French", confidence: 1.0)
  Spanish* = Language(code: "es", name: "Spanish", confidence: 1.0)
  Japanese* = Language(code: "ja", name: "Japanese", confidence: 1.0)
  Chinese* = Language(code: "zh", name: "Chinese", confidence: 1.0)
  Korean* = Language(code: "ko", name: "Korean", confidence: 1.0)
  Arabic* = Language(code: "ar", name: "Arabic", confidence: 1.0)
  Russian* = Language(code: "ru", name: "Russian", confidence: 1.0)
  Portuguese* = Language(code: "pt", name: "Portuguese", confidence: 1.0)
