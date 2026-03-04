---
applyTo: '**/*.py'
description: 'Python coding conventions and guidelines'
---

# Python Coding Conventions
Focus on substance over praise. Skip unnecessary compliments or praise that lacks depth. Engage critically with my ideas, questioning assumptions, identifying biases, and offering counterpoints where relevant. Don’t shy away from disagreement when it’s warranted, and ensure that any agreement is grounded in reason and evidence.

## Requirements
- **Compatibility**: Python 3.11+
- **Language Features**: Use the newest features when possible:
  - Pattern matching
  - Type hints
  - f-strings (preferred over `%` or `.format()`)
  - Dataclasses
  - Walrus operator
- **Follow Modern Python Standards**: Follow PEP 517, PEP 518, PEP 621, PEP 723 standards

## Anti-Patterns to Avoid

| Avoid | Use Instead |
|-------|-------------|
| `[tool.ty]` python-version | `[tool.ty.environment]` python-version |
| `uv pip install` | `uv add` and `uv sync` |
| Editing pyproject.toml manually to add deps | `uv add <pkg>` / `uv remove <pkg>` |
| `hatchling` build backend | `uv_build` (simpler, sufficient for most cases) |
| Poetry | uv (faster, simpler, better ecosystem integration) |
| requirements.txt | PEP 723 for scripts, pyproject.toml for projects |
| mypy / pyright | ty (faster, from Astral team) |
| `[project.optional-dependencies]` for dev tools | `[dependency-groups]` (PEP 735) |
| Manual virtualenv activation (`source .venv/bin/activate`) | `uv run <cmd>` |
| pre-commit | prek (faster, no Python runtime needed) |

**Key principles:**
- Always use `uv add` and `uv remove` to manage dependencies
- Never manually activate or manage virtual environments—use `uv run` for all commands
- Use `[dependency-groups]` for dev/test/docs dependencies, not `[project.optional-dependencies]`

## Library Overview
| Library | Usage |
|------|---------|
| **rich** | CLI output |
| **textual** | Building TUI |
| **click** | Argument parsing |


## Tool Overview

| Tool | Purpose | Replaces |
|------|---------|----------|
| **uv** | Package/dependency management | pip, virtualenv, pip-tools, pipx, pyenv |
| **ruff** | Linting AND formatting | flake8, black, isort, pyupgrade, pydocstyle |
| **ty** | Type checking | mypy, pyright (faster alternative) |
| **pytest** | Testing with coverage | unittest |
| **prek** | Pre-commit hooks | pre-commit (faster, Rust-native) |

### Security Tools

| Tool | Purpose | When It Runs |
|------|---------|--------------|
| **shellcheck** | Shell script linting | pre-commit |
| **detect-secrets** | Secret detection | pre-commit |
| **actionlint** | Workflow syntax validation | pre-commit, CI |
| **zizmor** | Workflow security audit | pre-commit, CI |
| **pip-audit** | Dependency vulnerability scanning | CI, manual |
| **Dependabot** | Automated dependency updates | scheduled |

## Style Guide
- **Tone**: Friendly and informative
- **Perspective**: Use second-person ("you" and "your") for user-facing messages
- **Formatting in Messages**:
  - Use backticks for: file paths, filenames, variable names, field entries
  - Use sentence case for titles and messages (capitalize only the first word and proper nouns)
  - Avoid abbreviations when possible
- **Type hints**: Add type hints to all functions, methods, and variables
- **Docstrings**: Use Google style docstrings
- **Import organization**: Follow isort standards
- **Configuration files**: Use `pyproject.toml` for project configuration
- **Logging**: Use the `logging` module for debug and info messages instead of print statements. Prefer lazy logging.

## Security
- Never commit secrets or API keys
- Use environment variables for sensitive configuration
- Validate all external inputs
- Use secure HTTP headers for API requests

## Best Practices Checklist

- [ ] Use `src/` layout for packages
- [ ] Set `requires-python = ">=3.11"`
- [ ] Configure ruff with `select = ["ALL"]` and explicit ignores
- [ ] Use ty for type checking
- [ ] Enforce test coverage minimum (80%+)
- [ ] Use dependency groups instead of extras for dev tools
- [ ] Add `uv.lock` to version control
- [ ] Use PEP 723 for standalone scripts

## CLI Argument Parsing

### click
Use the `click` framework

```python
import click


@click.command()
@click.option("-v", "--verbose", is_flag=True)
@click.argument("input_file", type=click.Path(exists=True))
@click.pass_context
def main(ctx: click.Context, verbose: bool, input_file: str) -> None:
    """Process input files."""
    ctx.exit(0)  # Explicit exit code
```

Use `@click.group()` for subcommands, `ctx.exit(code)` for exit codes, and `ctx.fail(message)` for errors.

## Type Hints

Use Python 3.11+ syntax with built-in generics.

```python
from pathlib import Path
from typing import Literal, Self


def process_items(items: list[str]) -> dict[str, int]:  # Built-in generics
    return {item: len(item) for item in items}


def read_file(path: str | Path) -> str:  # Union with pipe
    return Path(path).read_text(encoding="utf-8")


def find_config(name: str) -> Path | None:  # Optional with pipe
    config = Path(name)
    return config if config.exists() else None


def set_level(level: Literal["debug", "info", "warning"]) -> None:  # Constrained values
    pass


class Builder:
    def add(self, item: str) -> Self:  # Fluent interface
        self.items.append(item)
        return self
```

Use `list[str]` not `typing.List[str]`, `str | None` not `Optional[str]`, `Literal` for constrained values, `Self` for chained methods.


## Error Handling

Handle interrupts and pipe errors at the top level.

```python
import sys


def main() -> int:
    """Main entry point with error handling."""
    try:
        return run()
    except KeyboardInterrupt:
        print("\nInterrupted by user", file=sys.stderr)
        return 130
    except BrokenPipeError:
        sys.stderr.close()
        return 1
    except Exception as e:
        print(f"Error: {e}", file=sys.stderr)
        return 1
```

Custom exceptions can carry exit codes:

```python
class ScriptError(Exception):
    def __init__(self, message: str, exit_code: int = 1) -> None:
        super().__init__(message)
        self.exit_code = exit_code
```

## Documentation

Use Google-style docstrings with Args, Returns, Raises, and Example sections.

```python
def process_data(data: list[str], *, normalize: bool = False) -> dict[str, int]:
    """Process input data and return statistics.

    Args:
        data: List of strings to process.
        normalize: If True, normalize values before processing.

    Returns:
        Dictionary mapping processed items to their counts.

    Raises:
        ValueError: If data is empty.

    Example:
        >>> process_data(["a", "b", "a"])
        {'a': 2, 'b': 1}
    """
```

Include module docstrings with description, usage, and examples.

## Inline Script Metadata

PEP 723 inline metadata enables automatic dependency installation with *uv*.

```python
#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = [
#     "click>=8.0",
#     "rich>=13.0",
# ]
# ///
```
