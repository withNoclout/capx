# Security policy

## Supported versions

| Version | Supported |
| --- | --- |
| 0.1.x | Yes |
| Earlier development builds | No |

Install the newest available patch release before reporting a problem.

## Report a vulnerability privately

Do not open a public issue for a suspected vulnerability. Use GitHub's private vulnerability reporting for this repository:

<https://github.com/withNoclout/capx/security/advisories/new>

Include:

- the CapX version and macOS version;
- affected behavior and expected security boundary;
- minimal reproduction steps;
- practical impact;
- whether the issue is already public; and
- a proof of concept that does not contain personal screenshots, credentials, or unrelated user data.

The maintainer will acknowledge the report as soon as practical, investigate it privately, and coordinate disclosure after a fix is available. Please allow reasonable time for remediation before publishing details.

## Security boundaries

CapX is designed to read only a user-selected folder, keep thumbnails in memory, and operate without a network client. Reports involving bookmark scope, unintended file access, unsafe file handling, code signing, release integrity, or privacy regressions are in scope.

Reports that require a user to run a modified build, disable macOS protections, or grant unrelated software full control may be closed if they do not demonstrate an additional CapX vulnerability.
