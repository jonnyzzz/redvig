# Licenses: the `/licenses` folder

Every third-party component has **one file** in `/licenses`, whatever its license requires:
`licenses/<id>.cdx.json`, a CycloneDX 1.6 JSON BOM describing that one component in
`metadata.component`.

## Which components

Anything third-party that we ship, that our install scripts download, whose code we copied or adapted,
that our build and release use, or that redvig.dev serves. Code we wrote ourselves, including our own
earlier private projects, needs no file.

## Required content

- `name`, exact `version`, `supplier.name`, `purl` if one exists, `copyright`, and an `externalReferences`
  website link.
- `licenses`: one entry per license, with the SPDX `id` (or `name`) and the **full license text** in
  `text.content`. The SPDX expression goes in the property `redvig:license-expression`.
- Properties: `redvig:usage` (`bundled`, `downloaded`, `derived-source`, `build-tool`, or `website`;
  repeat the property if several apply), and `redvig:notice` with the upstream NOTICE text if there is
  one.

## Rules

- The change that adds, upgrades, or removes a component also adds, updates, or removes its file.
- Copied or adapted files keep their upstream copyright header and say they were modified.
- Every release ships `THIRD-PARTY-NOTICES.txt` generated from all `bundled`, `downloaded`, and
  `derived-source` files.
- CI checks every file against the CycloneDX 1.6 schema, and checks that every third-party module in a
  release has a `license` id with a matching file.

## First entries

- `mcp-steroid` (Apache-2.0, with its NOTICE): the install templates, launcher, and update logic are
  adapted from it.
- The third-party modules of the first release (for a JVM core: Amazon Corretto and Azul Zulu).
- The Hugo image and OpenSSH (`build-tool`).
