## Summary

Describe the template or registry change and its intended user.

## Licensing and prerequisites

- Generated source license:
- Dependency licenses:
- Build/runtime prerequisites:

## Validation

- [ ] I updated the template version when package bytes changed.
- [ ] I ran `.\eng\build.ps1`.
- [ ] I ran `.\eng\validate.ps1`.
- [ ] I reviewed the generated `dist/registry.json` changes.
- [ ] The template contains no hooks, command execution, installers, or
      network-dependent generation.
- [ ] Generated output remains useful after it is detached from Klonker.
