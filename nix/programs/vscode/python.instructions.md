---
applyTo: '**/*.py'
description: 'Python coding conventions and guidelines'
---

# Python Coding Conventions
Focus on substance over praise. Skip unnecessary compliments or praise that lacks depth. Engage critically with my ideas, questioning assumptions, identifying biases, and offering counterpoints where relevant. Don’t shy away from disagreement when it’s warranted, and ensure that any agreement is grounded in reason and evidence.

## Requirements
- **Compatibility**: Python 3.10+
- **Language Features**: Use the newest features when possible:
  - Pattern matching
  - Type hints
  - f-strings (preferred over `%` or `.format()`)
  - Dataclasses
  - Walrus operator

## Tools
- **Formatting**: Ruff
- **Linting**: Ruff
- **Testing**: pytest with plain functions and fixtures

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
