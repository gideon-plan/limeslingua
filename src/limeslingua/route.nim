## route.nim -- Route text to language-specific collection based on detected language.

{.experimental: "strict_funcs".}

import std/tables
import basis/code/choice, detect

# =====================================================================================================================
# Types
# =====================================================================================================================

type
  RouteConfig* = object
    collection_map*: Table[string, string]  ## language code -> collection name
    default_collection*: string

  RouteResult* = object
    collection*: string
    language*: Language
    fallback*: bool  ## true if default collection was used

# =====================================================================================================================
# Routing
# =====================================================================================================================

proc default_route_config*(prefix: string = "vectors"): RouteConfig =
  var m: Table[string, string]
  m["en"] = prefix & "_en"
  m["de"] = prefix & "_de"
  m["fr"] = prefix & "_fr"
  m["es"] = prefix & "_es"
  m["ja"] = prefix & "_ja"
  m["zh"] = prefix & "_zh"
  RouteConfig(collection_map: m, default_collection: prefix & "_default")

proc route*(text: string, detect_fn: DetectFn,
            config: RouteConfig = default_route_config()
           ): Choice[RouteResult] =
  ## Detect language and route to appropriate collection.
  let lang = detect_fn(text)
  if lang.is_bad:
    return bad[RouteResult](lang.err)
  let code = lang.val.code
  if code in config.collection_map:
    good(
      RouteResult(collection: config.collection_map[code],
                  language: lang.val, fallback: false))
  else:
    good(
      RouteResult(collection: config.default_collection,
                  language: lang.val, fallback: true))

proc route_with_language*(lang: Language,
                          config: RouteConfig = default_route_config()
                         ): RouteResult =
  ## Route when language is already known.
  if lang.code in config.collection_map:
    RouteResult(collection: config.collection_map[lang.code],
                language: lang, fallback: false)
  else:
    RouteResult(collection: config.default_collection,
                language: lang, fallback: true)
