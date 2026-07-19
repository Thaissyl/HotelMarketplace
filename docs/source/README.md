# Source Specifications

This directory contains Markdown conversions of the authoritative project
specifications. The Markdown files preserve headings, lists, tables, links, and
embedded diagrams so they can be reviewed and searched alongside the codebase.

## Canonical Documents

| Document | Markdown | Original source | SHA-256 |
| --- | --- | --- | --- |
| Software Design Document | [software-design-document.md](software-design-document.md) | `D:\hotel-management-srs\software-design-document.docx` | `C8D0A7A679EDE6DBF43020C9A359C6E198830E9F10B5557FAFCDB147DBFFC0DE` |
| Software Requirement Document | [software-requirement-document.md](software-requirement-document.md) | `D:\hotel-management-srs\software-requirement-document.docx` | `D6F1E6F35BA571884F420D14F9E7DC291AB13A41232E3B09F5BB1A7EB3DC4381` |

The canonical Markdown files are generated artifacts. Business requirement
changes must be made in the original Word documents and then reconverted to
avoid uncontrolled divergence between formats.

## Conversion

The documents were converted with Microsoft MarkItDown 0.1.6 and a local image
asset exporter. Embedded images are stored under `assets/` and referenced with
relative paths so previews work in source-control viewers and Markdown editors.

The legacy `srs-final-mvp-semantic-repair.md` conversion is retained for
traceability. Its textual content is identical to
`software-requirement-document.md`; only its image asset path names differ.
