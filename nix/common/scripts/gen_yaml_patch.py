#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = [
#     "click>=8.1.7",
#     "pyyaml>=6.0.1",
#     "rich>=13.7.0",
# ]
# ///

import sys
from pathlib import Path
from typing import Any

import click
import yaml
from rich.console import Console

console = Console()


def get_yaml_diff(original: dict[str, Any], updated: dict[str, Any]) -> dict[str, Any]:
    """Compare two YAML dictionaries and extract the differences.

    Args:
        original: The base dictionary to compare against.
        updated: The new dictionary containing potential changes.

    Returns:
        Dictionary containing only the keys and values that differ or are new.

    Example:
        >>> get_yaml_diff({'a': 1, 'b': {'c': 2}}, {'a': 1, 'b': {'c': 3, 'd': 4}})
        {'b': {'c': 3, 'd': 4}}
    """
    diff: dict[str, Any] = {}
    for key, value in updated.items():
        if key not in original:
            diff[key] = value
        elif isinstance(value, dict) and isinstance(original[key], dict):
            nested_diff = get_yaml_diff(original[key], value)
            if nested_diff:
                diff[key] = nested_diff
        elif original[key] != value:
            diff[key] = value
            
    return diff


@click.command()
@click.argument("original_file", type=click.Path(exists=True, dir_okay=False, path_type=Path))
@click.argument("updated_file", type=click.Path(exists=True, dir_okay=False, path_type=Path))
@click.option(
    "-o",
    "--output",
    "output_file",
    type=click.Path(dir_okay=False, writable=True, path_type=Path),
    default=Path("patch.yaml"),
    help="Filename for the generated patch output.",
)
@click.pass_context
def main(ctx: click.Context, original_file: Path, updated_file: Path, output_file: Path) -> None:
    """Generate a patch by finding differences between two YAML files.

    Reads ORIGINAL_FILE and UPDATED_FILE, extracts the changed or added
    fields, and writes them to the output file.
    """
    try:
        with original_file.open("r", encoding="utf-8") as f1, updated_file.open("r", encoding="utf-8") as f2:
            old_yaml = yaml.safe_load(f1) or {}
            new_yaml = yaml.safe_load(f2) or {}

        # Ensure top-level structure is a dictionary
        if not isinstance(old_yaml, dict) or not isinstance(new_yaml, dict):
            console.print("[bold red]Error: Both YAML files must contain top-level mappings (dictionaries).[/bold red]")
            ctx.exit(1)

        diff_yaml = get_yaml_diff(old_yaml, new_yaml)

        if not diff_yaml:
            console.print("[yellow]No differences found![/yellow]")
            ctx.exit(0)

        with output_file.open("w", encoding="utf-8") as out:
            yaml.dump(diff_yaml, out, default_flow_style=False, sort_keys=False)

        console.print(f"[green]✅ Extracted changes successfully to: [bold]{output_file}[/bold][/green]")

    except yaml.YAMLError as e:
        console.print(f"[bold red]Failed to parse YAML file:[/bold red] {e}")
        ctx.exit(1)
    except Exception as e:
        console.print(f"[bold red]An unexpected error occurred:[/bold red] {e}")
        ctx.exit(1)


if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        console.print("\n[bold yellow]Interrupted by user[/bold yellow]", style="bold")
        sys.exit(130)
    except BrokenPipeError:
        sys.stderr.close()
        sys.exit(1)
