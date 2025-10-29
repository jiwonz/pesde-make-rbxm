# pesde-make-rbxm
A simple pesde binary to make RBXM from pesde Roblox packages

## Usage
```sh
pesde x jiwonz/pesde_make_rbxm -- gh#alicesaidhi/vide#ebbf823 --output vide.rbxm --provider mise
```

## What does this script do?
This script creates a pesde project in a temporary directory, installs the given packages, and builds rbxm using rojo via the provider.

## Supported Providers
- [ ] rokit
- [ ] aftman
- [x] mise
- [ ] pesde

If no provider is given, it will look for rojo in the current environment!
