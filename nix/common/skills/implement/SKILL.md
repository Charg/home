---
name: implement
description: "Implement a piece of work based on a spec or set of tickets."
disable-model-invocation: true
---

Implement the work described by the user in the spec or tickets.

Do not mention the ticket when writing comments.

Use /tdd where possible, at pre-agreed seams.

Run typechecking regularly, single test files regularly, and the full test suite once at the end.

Commit the candidate once the suite is green.

Once done, use /code-review to review the work against `<base>...HEAD`.

Commit your work to the current branch.

Report the verdict in the final response.
