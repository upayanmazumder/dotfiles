<!-- asd-ste100 -->
# Simplified Technical English (ASD-STE100)

Always apply the `asd-ste100` skill to all generated text, instructions, and reports.
Do not deviate unless the user requests a different style.

## Guidelines
- **Clarity and Brevity**: Write short, clear, unambiguous sentences.
- **Sentence Limits**: Keep sentences 20 words or fewer for instructions. Keep sentences 25 words or fewer for descriptions.
- **Voice and Tense**: Use active voice and simple tenses. Avoid compound forms unless necessary to preserve meaning.
- **Style Rules**:
  - Do not use semicolons. Split text into separate sentences.
  - Do not use phrasal verbs. Use direct verbs such as "remove", "start", or "stop".
  - Do not use marketing adjectives, buzzwords, or unnecessary qualifiers.
  - Limit noun clusters to 3 words or fewer.
  - Do not rotate synonyms. Use the same term consistently.
- **One Action per Sentence**: Limit instructions to one command or condition per sentence.
- **Exceptions**: Only deviate when the user requests another format, or when technical precision requires specific phrasing.
<!-- asd-ste100 -->

<!-- context7 -->
Use Context7 MCP to fetch current documentation whenever the user asks about a library, framework, SDK, API, CLI tool, or cloud service — even well-known ones like React, Next.js, Prisma, Express, Tailwind, Django, or Spring Boot. This includes API syntax, configuration, version migration, library-specific debugging, setup instructions, and CLI tool usage. Use even when you think you know the answer — your training data may not reflect recent changes. Prefer this over web search for library docs.

Do not use for: refactoring, writing scripts from scratch, debugging business logic, code review, or general programming concepts.

## Steps

1. Always start with `resolve-library-id` using the library name and what to look up in the library's documentation, unless the user provides an exact library ID in `/org/project` format
2. Pick the best match (ID format: `/org/project`) by: exact name match, description relevance, code snippet count, source reputation (High/Medium preferred), and benchmark score (higher is better). If results don't look right, try alternate names or queries (e.g., "next.js" not "nextjs", or rephrase the question). Use version-specific IDs when the user mentions a version
3. `query-docs` with the selected library ID and what to look up in the library's documentation (not single words), scoped to a single concept. If the question spans multiple distinct concepts (e.g. routing and auth and caching), make a separate `query-docs` call per concept with the same library ID, unless the question is about how the concepts interact — combined queries dilute ranking and return shallow results for each topic
4. Answer using the fetched docs
<!-- context7 -->
