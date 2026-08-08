# Dotfiles Management

This context describes how configuration stored in the repository is projected into filesystem locations used by applications.

## Language

**Manifest container**:
A directory containing `manage.json`. It declares a platform set and target set, and its immediate children other than the manifest are its managed entries. Discovery does not descend beneath it.
_Avoid_: Package, source folder

**Platform set**:
The unordered, duplicate-free collection of operating systems that activate a manifest container. The supported values are `macos` and `linux`.
_Avoid_: Platform target, operating-system targets

**Managed entry**:
An immediate child of an active manifest container other than `manage.json` that resolves within the container boundary. Every managed entry participates in fan-out; broken entries are invalid.
_Avoid_: Managed source, source target, managed target

**Target directory**:
A filesystem directory that receives links to every managed entry in an active manifest container.
_Avoid_: Destination, install location

**Target set**:
The unordered, duplicate-free collection of target directories declared by one manifest.
_Avoid_: Target list, target sequence

**Fan-out**:
The relationship in which every managed entry in an active manifest container is linked into every declared target directory.
_Avoid_: Routing, one-to-one mapping
