---
name: Kanagawa domain issue
about: Implementation of a TSE accountability rule or feature in the kanagawa engine
title: "[Onda N] <short title>"
labels: ["kanagawa", "kanagawa:milestone-N"]
assignees: []
---

## Manual citation

<!--
Cite the exact section(s) of Res. TSE nº 23.432/14 and/or the manual (TRE-SC).
Example:
  Res. TSE 23.432/14, item XXIV, alíneas j–r
  Lei nº 9.096/1995, art. 44
  Manual TRE-SC p. 37
-->

## Problem

<!-- One paragraph: what problem does this solve for the party treasurer / accountant? -->

## Acceptance criteria

<!-- Checklist of observable, testable behaviours. Each item must be verifiable without reading code. -->

- [ ] ...
- [ ] ...
- [ ] All user-facing strings go through `t("kanagawa.*")`; pt-BR and en populated
- [ ] No changes outside `engines/kanagawa/` (verified by `git diff main -- . ':!engines/kanagawa/'`)

## Affected files (inside `engines/kanagawa/` only)

- `engines/kanagawa/app/models/kanagawa/...`
- `engines/kanagawa/app/controllers/kanagawa/...`
- `engines/kanagawa/db/migrate/...`
- `engines/kanagawa/config/locales/kanagawa.<locale>.yml`
- `engines/kanagawa/test/...`

## Tests

- [ ] Model test covering the domain rule cited above
- [ ] Controller test for the `/b/...` endpoints touched
- [ ] i18n smoke test: requesting the page with `I18n.locale = :"pt-BR"` and `:en` renders without `translation missing`

## Out of scope

<!-- Anything that looks related but belongs to another milestone or issue. Link the other issue if applicable. -->

## Notes / references

<!-- Links to the manual PDF pages, prior commits, related issues, etc. -->
