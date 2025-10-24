# Granch

## Interactive Git Branch Creator with Conventional Naming

A Terminal User Interface (TUI) application for creating Git branches following conventional naming patterns. Built with Go and Bubble Tea, Granch streamlines branch creation by guiding you through a simple two-step selection process.

## Features

- **Interactive Branch Selection**: Browse and select from your existing branches, sorted by most recently updated
- **Category-Based Naming**: Follows conventional commit prefixes for consistent branch naming
- **Automatic Naming**: Generates unique branch names with UUID-based identifiers
- **Current Branch Detection**: Automatically highlights your current branch in the list
- **Zero Configuration**: Works out of the box in any Git repository
- **Keyboard-Driven**: Fast and efficient navigation with arrow keys

## Branch Naming Convention

Granch creates branches following this pattern:

```bash
@{category}/{uuid}
```

Where:

- `{category}` is one of: `ci`, `feat`, `fix`, `perf`, `refactor`, `test`
- `{uuid}` is the first 8 characters of a randomly generated UUID

**Example branches:**

```text
@feat/a3b2c1d4
@fix/9e8f7a6b
@refactor/2c3d4e5f
```

This convention is inspired by [Conventional Commits](https://www.conventionalcommits.org/) and follows Git branch naming best practices.

## Categories

| Category | Code | Use Case |
|----------|------|----------|
| CI/CD | `ci` | Pipeline, workflow, or automation changes |
| Feature | `feat` | New features or enhancements |
| Fix | `fix` | Bug fixes |
| Performance | `perf` | Performance improvements |
| Refactor | `refactor` | Code refactoring without changing functionality |
| Test | `test` | Adding or updating tests |

## Why This Naming Convention?

The `@{category}/{uuid}` format offers several advantages:

1. **Consistency**: All branches follow the same predictable pattern
2. **Categorization**: Easy to filter and organize branches by type
3. **Uniqueness**: UUIDs prevent naming conflicts
4. **Machine-Readable**: The `@` prefix makes branches easily identifiable in scripts
5. **Brevity**: Short UUIDs keep names concise while maintaining uniqueness

## Prerequisites

- **Go 1.16+**: Required to build and run the application
- **Git**: Must be installed and accessible from your PATH
- **Git Repository**: Run Granch from within a Git repository

## Installation

### From Source

```bash
git clone <https://github.com/tejaromalius/granch.git>
cd granch
go mod tidy
go build -o granch
sudo mv granch /usr/local/bin/
```

### Quick Install

If you have Go installed, you can install directly:

```bash
go install github.com/Tejaromalius/Granch@latest
```

## License

MIT License - feel free to use and modify as needed.

## Acknowledgments

- [**Charm**](https://charm.sh/) for the excellent Bubble Tea framework
- [**Conventional Commits Specification**](https://www.conventionalcommits.org/)
- [**Git Branch Naming Best Practices**](https://github.com/trending)
