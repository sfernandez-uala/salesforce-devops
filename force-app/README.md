# force-app — the default package directory

Empty on purpose, and tracked so that it exists.

`sfdx-project.json` marks this directory `default: true`, which makes it the
landing zone: metadata pulled down by `sf project retrieve start` that is not
already tracked in source is written here. Before this directory existed the
default was `view360`, and retrieving anything unrelated dropped it inside the
feature — a Contact layout is what surfaced it.

So this is where unclassified org metadata arrives, to be reviewed and moved
into the directory it belongs to:

| Directory  | Holds                                                        |
|------------|--------------------------------------------------------------|
| `shared/`  | components with no domain: no `c/` import, no mention of v360 |
| `view360/` | the Vista 360 product                                        |
| `demo/`    | the test FlexiPage and components that only demonstrate      |

Git does not track empty directories, so without this file the path is absent
from a fresh checkout and every `sf` command fails with
`MissingPackageDirectoryError: The path "force-app" ... does not exist`.
