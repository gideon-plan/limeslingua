## tlimeslingua.nim -- Tests for limeslingua multilingual vector search.

{.experimental: "strict_funcs".}

import std/unittest
import limeslingua

# =====================================================================================================================
# Detect tests
# =====================================================================================================================

suite "detect":
  test "language constructor":
    let lang = language("en", "English", 0.99)
    check lang.code == "en"
    check lang.name == "English"
    check lang.confidence == 0.99

  test "is_language check":
    check is_language(English, "en")
    check not is_language(English, "de")

  test "detect with mock":
    let mock_detect: DetectFn = proc(text: string): Result[Language, BridgeError] {.raises: [].} =
      Result[Language, BridgeError].good(English)
    let result = detect("Hello world", mock_detect)
    check result.is_good
    check result.val.code == "en"

  test "common languages defined":
    check English.code == "en"
    check German.code == "de"
    check French.code == "fr"
    check Japanese.code == "ja"
    check Chinese.code == "zh"

# =====================================================================================================================
# Normalize tests
# =====================================================================================================================

suite "normalize":
  test "lowercase normalization":
    let config = NormConfig(form: nfNone, lowercase: true,
                            strip_whitespace: false, collapse_whitespace: false)
    check normalize_text("Hello WORLD", config) == "hello world"

  test "whitespace collapse":
    let config = NormConfig(form: nfNone, lowercase: false,
                            strip_whitespace: true, collapse_whitespace: true)
    check normalize_text("  hello   world  ", config) == "hello world"

  test "default config":
    let result = normalize_text("  Hello   WORLD  ")
    check result == "hello world"

  test "detect script Latin":
    check detect_script("Hello world") == scLatin

  test "detect script Cyrillic":
    check detect_script("Привет мир") == scCyrillic

  test "detect script CJK":
    check detect_script("こんにちは世界") == scCJK

  test "normalize for language delegates":
    let result = normalize_for_language("  HELLO  ", English)
    check result == "hello"

# =====================================================================================================================
# Route tests
# =====================================================================================================================

suite "route":
  test "route known language":
    let mock_detect: DetectFn = proc(text: string): Result[Language, BridgeError] {.raises: [].} =
      Result[Language, BridgeError].good(English)
    let result = route("Hello", mock_detect)
    check result.is_good
    check result.val.collection == "vectors_en"
    check not result.val.fallback

  test "route unknown language falls back":
    let mock_detect: DetectFn = proc(text: string): Result[Language, BridgeError] {.raises: [].} =
      Result[Language, BridgeError].good(language("sw", "Swahili"))
    let result = route("Habari", mock_detect)
    check result.is_good
    check result.val.collection == "vectors_default"
    check result.val.fallback

  test "route_with_language known":
    let result = route_with_language(German)
    check result.collection == "vectors_de"
    check not result.fallback

  test "route_with_language unknown":
    let result = route_with_language(language("tl", "Tagalog"))
    check result.collection == "vectors_default"
    check result.fallback

# =====================================================================================================================
# Search tests
# =====================================================================================================================

suite "search":
  test "cross-lingual search merges by score":
    let mock_embed: EmbedQueryFn = proc(t: string): Result[seq[float32], BridgeError] {.raises: [].} =
      Result[seq[float32], BridgeError].good(@[1.0'f32])
    let mock_search: CollectionSearchFn = proc(c: string, q: seq[float32], k: int): Result[seq[SearchResult], BridgeError] {.raises: [].} =
      if c == "vectors_en":
        Result[seq[SearchResult], BridgeError].good(@[
          SearchResult(text: "english doc", score: 0.9, collection: c, language: English)])
      else:
        Result[seq[SearchResult], BridgeError].good(@[
          SearchResult(text: "german doc", score: 0.8, collection: c, language: German)])
    let config = SearchConfig(top_k: 5, collections: @["vectors_en", "vectors_de"],
                              merge_strategy: msScoreRank)
    let result = search_cross_lingual("query", mock_embed, mock_search, config)
    check result.is_good
    check result.val.len == 2
    check result.val[0].score >= result.val[1].score  # sorted by score
    check result.val[0].text == "english doc"

  test "cross-lingual search skips failing collections":
    let mock_embed: EmbedQueryFn = proc(t: string): Result[seq[float32], BridgeError] {.raises: [].} =
      Result[seq[float32], BridgeError].good(@[1.0'f32])
    let mock_search: CollectionSearchFn = proc(c: string, q: seq[float32], k: int): Result[seq[SearchResult], BridgeError] {.raises: [].} =
      if c == "vectors_en":
        Result[seq[SearchResult], BridgeError].good(@[
          SearchResult(text: "ok", score: 0.9, collection: c, language: English)])
      else:
        Result[seq[SearchResult], BridgeError].bad(BridgeError(msg: "collection unavailable"))
    let config = default_search_config(@["vectors_en", "vectors_de"])
    let result = search_cross_lingual("query", mock_embed, mock_search, config)
    check result.is_good
    check result.val.len == 1

  test "search single collection":
    let mock_embed: EmbedQueryFn = proc(t: string): Result[seq[float32], BridgeError] {.raises: [].} =
      Result[seq[float32], BridgeError].good(@[1.0'f32])
    let mock_search: CollectionSearchFn = proc(c: string, q: seq[float32], k: int): Result[seq[SearchResult], BridgeError] {.raises: [].} =
      Result[seq[SearchResult], BridgeError].good(@[
        SearchResult(text: "result", score: 0.95, collection: c, language: English)])
    let result = search_single_collection("query", "vectors_en", mock_embed, mock_search)
    check result.is_good
    check result.val.len == 1
