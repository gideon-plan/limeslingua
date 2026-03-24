## search.nim -- Cross-lingual search across multiple language collections.
##
## Query in one language, retrieve from multiple collections, merge results.

{.experimental: "strict_funcs".}

import std/[algorithm, tables]
import lattice, detect

# =====================================================================================================================
# Types
# =====================================================================================================================

type
  SearchResult* = object
    text*: string
    score*: float32
    collection*: string
    language*: Language
    metadata*: Table[string, string]

  SearchConfig* = object
    top_k*: int
    collections*: seq[string]  ## Collections to search across
    merge_strategy*: MergeStrategy

  MergeStrategy* = enum
    msInterleave   ## Round-robin from each collection
    msScoreRank    ## Sort all results by score

  CollectionSearchFn* = proc(collection: string, query_embedding: seq[float32],
                             top_k: int): Result[seq[SearchResult], BridgeError] {.raises: [].}

  EmbedQueryFn* = proc(text: string): Result[seq[float32], BridgeError] {.raises: [].}

# =====================================================================================================================
# Configuration
# =====================================================================================================================

proc default_search_config*(collections: seq[string]): SearchConfig =
  SearchConfig(top_k: 10, collections: collections, merge_strategy: msScoreRank)

# =====================================================================================================================
# Cross-lingual search
# =====================================================================================================================

proc search_cross_lingual*(query: string, embed_fn: EmbedQueryFn,
                           search_fn: CollectionSearchFn,
                           config: SearchConfig
                          ): Result[seq[SearchResult], BridgeError] =
  ## Search across multiple language collections and merge results.
  let qemb = embed_fn(query)
  if qemb.is_bad:
    return Result[seq[SearchResult], BridgeError].bad(qemb.err)
  var all_results: seq[SearchResult]
  for coll in config.collections:
    let results = search_fn(coll, qemb.val, config.top_k)
    if results.is_bad:
      continue  # Skip failing collections
    all_results.add(results.val)
  case config.merge_strategy
  of msScoreRank:
    all_results.sort(proc(a, b: SearchResult): int =
      if a.score > b.score: -1
      elif a.score < b.score: 1
      else: 0)
  of msInterleave:
    discard  # Already interleaved by collection order
  # Trim to top_k
  if all_results.len > config.top_k:
    all_results.setLen(config.top_k)
  Result[seq[SearchResult], BridgeError].good(all_results)

proc search_single_collection*(query: string, collection: string,
                               embed_fn: EmbedQueryFn,
                               search_fn: CollectionSearchFn,
                               top_k: int = 10
                              ): Result[seq[SearchResult], BridgeError] =
  ## Search a single collection.
  let qemb = embed_fn(query)
  if qemb.is_bad:
    return Result[seq[SearchResult], BridgeError].bad(qemb.err)
  search_fn(collection, qemb.val, top_k)
