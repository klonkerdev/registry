# Security policy

Template registries are a supply-chain boundary. Please report suspected path
escape, unsafe extraction, checksum bypass, executable template behavior,
license misrepresentation, or compromised publication artifacts privately.

Use GitHub's private vulnerability reporting or create a private repository
security advisory for `klonkerdev/registry`. Do not open a public issue with
working exploit details before maintainers have had an opportunity to assess
and address the report.

Include:

- the affected template ID and version;
- the affected index or package URL;
- expected and observed behavior;
- reproduction steps or a minimal malicious package;
- impact and any known mitigations.

The latest version of each package listed by `dist/registry.json` is supported.
Older generated projects are detached from Klonker and are not managed or
updated by this registry.

SHA-256 values in the index provide integrity checking, not publisher
authentication. Package signatures and key rotation are planned separately.
