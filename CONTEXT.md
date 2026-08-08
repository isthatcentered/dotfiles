# Dotfiles Management

This context describes how configuration stored in the repository is projected into filesystem locations used by applications.

## Language

**Managed source**:
A file or directory owned by a package and selected for linking into the filesystem.
_Avoid_: Source target, managed target

**Target directory**:
A platform-specific filesystem directory that receives links to every managed source in its package.
_Avoid_: Destination, install location

**Target set**:
The unordered, duplicate-free collection of target directories selected for one package and platform.
_Avoid_: Target list, target sequence

**Fan-out**:
The relationship in which every managed source in a package is linked into every target directory selected for the active platform.
_Avoid_: Routing, one-to-one mapping
