# Security policy

Talkies is an open-source, local-first desktop application. Please report security vulnerabilities privately through GitHub's **Report a vulnerability** feature when available, or contact the maintainers listed in the repository. Do not publish details before a fix is available.

## Data and network behavior

Talkies is designed to process audio and transcripts locally. Optional model downloads contact the configured model host; model inference and transcript cleanup run on-device. Do not include private recordings or transcript content in public bug reports. The GitHub Pages website is static and does not provide accounts, analytics, or a Talkies-operated data service.

## Dependencies and model files

Review platform-specific dependency and model licenses before redistribution. Downloaded model artifacts should be verified against published checksums where provided. Keep operating systems, GPU/CPU runtimes, and application dependencies up to date.

## Historical material

The former hosted account and billing implementation is retained under `archive/frontend` for historical reference only. It is not part of the deployed site or supported product. The old Stripe provisioning script was removed because it contained credentials; if those credentials were ever active, revoke and rotate them.
