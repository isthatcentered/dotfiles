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

**Managed link**:
A symbolic link at a destination claimed by the current plan. It is correct when its stored target is the planned managed entry's absolute path; otherwise it may be replaced during reconciliation.
_Avoid_: Installed file, owned link

**Target directory**:
A filesystem directory that receives links to every managed entry in an active manifest container.
_Avoid_: Destination, install location

**Target set**:
The unordered, duplicate-free collection of target directories declared by one manifest.
_Avoid_: Target list, target sequence

**Fan-out**:
The relationship in which every managed entry in an active manifest container is linked into every declared target directory.
_Avoid_: Routing, one-to-one mapping

**Reconciliation**:
The process of making every destination in the current plan a correct managed link while leaving destinations outside that plan untouched.
_Avoid_: Cleanup, synchronization
