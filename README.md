# pesde-make-rbxm
A simple pesde binary to make RBXM(Roblox Studio Model File) from pesde Roblox packages

## Usage
```sh
pesde x jiwonz/pesde_make_rbxm -- --help
pesde x jiwonz/pesde_make_rbxm -- <package_name> --output package.rbxm
```

## Example
```sh
pesde x jiwonz/pesde_make_rbxm -- gh#alicesaidhi/vide#ebbf823 --provider mise
```

## What does this script do?
This script creates a pesde project in a temp directory, installs the given packages, and builds into RBXM using rojo which is managed via the given provider.

## Supported Providers
- [x] mise
- [x] pesde
- [ ] rokit (not tested)
- [ ] aftman (not tested)

If no provider is given, it will look for rojo in the current environment!
