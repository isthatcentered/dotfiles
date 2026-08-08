# Dotfiles Management

This context describes how configuration stored in the repository is projected into filesystem locations used by applications.

## Language

**Package**:
A non-empty collection of configuration entries that share the same target set.

**Managed entry**:
An immediate child of a package other than its manifest that resolves within the package boundary. Every managed entry participates in fan-out; broken entries are invalid.
_Avoid_: Managed source, source target, managed target

**Target directory**:
A platform-specific filesystem directory that receives links to every managed source in its package.
_Avoid_: Destination, install location

**Target set**:
The unordered, duplicate-free collection of target directories selected for one package and platform.
_Avoid_: Target list, target sequence

**Fan-out**:
The relationship in which every managed entry in a package is linked into every target directory selected for the active platform.
_Avoid_: Routing, one-to-one mapping
