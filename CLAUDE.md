# dotfiles operating rules

This repository tracks selected Sonder configuration. Read `README.md`, `docs/config-management.md`, and `docs/package-management.md` before changes to the live machine.

- Keep end-4 Illogical Impulse as an upstream dependency. Track only local overlays and owned additions.
- Never commit credentials, private endpoints, generated state, backups, or personal media without redistribution rights.
- Compare live files before deployment. Do not replace live configuration with an older repository copy.
- Review package lists before installation. Do not install OS-base packages or upstream Illogical Impulse packages through this repository.
- Run a secret scan and inspect staged changes before publication.
