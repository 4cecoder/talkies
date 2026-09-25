# Security policy

Talkies is an open-source, local-first desktop application. Please report security vulnerabilities privately through GitHub's **Report a vulnerability** feature when available, or contact the maintainers listed in the repository. Do not publish details before a fix is available.

## Data and network behavior

Talkies is designed to process audio and transcripts locally. Optional model downloads contact the configured model host; model inference and transcript cleanup run on-device. Do not include private recordings or transcript content in public bug reports. The GitHub Pages website is static and does not provide accounts, analytics, or a Talkies-operated data service.

## Dependencies and model files

Review platform-specific dependency and model licenses before redistribution. Downloaded model artifacts should be verified against published checksums where provided. Keep operating systems, GPU/CPU runtimes, and application dependencies up to date.

## Historical material

The former hosted account and billing implementation is retained under `archive/frontend` for historical reference only. It is not part of the deployed site or supported product.

The removed Stripe provisioning script contained hard-coded test-mode credentials. The script is absent from the current tree, but deleting it did not remove those values from Git history, and this repository is public. Treat the exposed credentials as compromised: revoke and rotate them in Stripe, then use GitHub's sensitive-data removal process to remove the affected history and cached views. Do not add the old script or credentials back to the repository.
