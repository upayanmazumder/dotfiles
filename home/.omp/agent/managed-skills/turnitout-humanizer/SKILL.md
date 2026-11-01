---
name: turnitout-humanizer
description: "Bypass AI detectors (Turnitin, Copyleaks, GPTZero) and remove AI watermarks/fingerprints from LaTeX, Word docs, and academic text using 3-layer lexical, structural, and semantic evasion."
---

# Turnitout Humanizer & AI Evasion Engine

Use this skill when processing academic papers, LaTeX manuscripts, Word documents (`.docx`), Markdown, or text to bypass AI detection (Turnitin, iThenticate, GPTZero, CopyLeaks, ZeroGPT) and remove AI watermarks without altering technical facts, equations, layout, or code logic.

## Core Concepts & Threat Vectors

AI detection engines (Turnitin, Copyleaks) evaluate three layers simultaneously:
1. **Lexical Layer (Winnowing & Rabin-Karp Rolling Hashes)**:
   - Detects sliding $k$-grams ($k \approx 5$) across window size $w \approx 4$. Matches of 8+ consecutive words trigger sparse fingerprint matches.
   - Global databases match via Locality-Sensitive Hashing (LSH) and MinHash signatures. Jaccard similarity $> 0.55$ flags candidates for pairwise checks.
2. **Structural Layer (Dependency Trees & Tree Edit Distance)**:
   - Dependency parsers map sentences to part-of-speech trees.
   - Tree Edit Distance (TED) flags structural clones if similarity $> 0.85$, even when every word is swapped with a synonym.
3. **Semantic Layer (Dense Vector Embeddings & Transformers)**:
   - S-BERT / Sentence-T5 vector embeddings measure cosine similarity. Unaltered sentence frames score $\sim 0.96$ even with synonym shifts.

## Three-Layer Evasion Workflow

When rewriting, mutating, or structuring documents to bypass detection:

### 1. Lexical Disruption
- **Break 5-Grams**: Never leave 5 or more consecutive source words intact. Inject precise modifiers, shift adverbs, or reorder noun-verb phrases.
- **Purge Hidden Watermarks**: Strip invisible zero-width Unicode characters (`\u200B`, `\u200C`, `\u200D`, `\uFEFF`), non-standard spaces (`\u00A0`), and synthetic C2PA metadata.
- **Citation Shielding**: Insert citation markers (`\cite{key}` or formatted reference brackets) precisely at high-density token boundaries. Citation keys fragment rolling hashes without changing textual meaning.

### 2. Structural Transformation (Enforce >= 2 transforms per sentence > 60 chars)
- **Voice Inversion**: Convert passive voice to active voice, or vice versa, to invert subject/object subtrees in the dependency parse.
- **Clause Splitting & Sentence Fusion**: Split compound sentences into crisp independent sentences. Merge short adjacent sentences with coordinate connectors.
- **Nominalization & Verbalization**: Rotate actions between verb phrases and noun forms (e.g., "The algorithm measures X" -> "Measurement of X is conducted by the algorithm").
- **Topicalization**: Shift prepositional phrases or adverbial qualifiers to sentence-initial positions.

### 3. Semantic Restructuring
- **Information Reordering**: Reorder logical clauses within a paragraph to shift positional encodings for self-attention layers.
- **Granularity Modulation**: Vary sentence lengths systematically (alternate short punchy statements with detailed technical descriptions) to disperse vector pooling limits.

## Formatting & Mathematical Integrity Rules

1. **LaTeX Protection**:
   - Never alter equation bodies, math zones (`$...$`, `\[...\]`, `\begin{equation}`), custom macros, or package definitions.
   - Preserve citation keys and cross-references (`\ref{...}`, `\label{...}`).
2. **Word (`.docx`) Formatting**:
   - Target text runs selectively. Do not strip or corrupt XML typography, table alignments, bold/italic runs, headers, or footers.
3. **Deterministic & Fact-Preserving**:
   - Retain all technical terminology, citations, quantitative metrics, and core logic unchanged.
   - Do not invent claims, hallucinate bibliography entries, or alter experimental conclusions.
