local argparse = require("../lune_packages/argparse")
local pathfs = require("../lune_packages/pathfs")
local dirs = require("../lune_packages/dirs")
local process = require("@lune/process")

local DEFAULT_PESDE_PATH = "pesde.toml"
local DEFAULT_PESDE_MANIFEST = table.freeze {
	name = "pesde/do_not_publish_this",
	version = "0.1.0",
	private = true,
	target = {
		environment = "roblox",
	},
	indices = {
		default = "https://github.com/pesde-pkg/index",
	},
	scripts = {
		roblox_sync_config_generator = ".pesde/scripts/roblox_sync_config_generator.luau",
		sourcemap_generator = ".pesde/scripts/sourcemap_generator.luau",
	},
	dev_dependencies = {
		scripts = { repo = "jiwonz/pesde-scripts", rev = "55d22c1", path = "dist/rojo" },
	},
	engines = {
		pesde = "^0.7.0",
		lune = "^0.10.2",
	},
}

type GetRojoContext = {
	exec: (program: string, params: { string }) -> ()
}

local getRojoByProvider: { [string]: ((context: GetRojoContext) -> ())? } = {
	mise = function(context)
		context.exec("mise", { "setting", "--local", "experimental=true" })
		context.exec("mise", { "use", "github:rojo-rbx/rojo", "--yes" })
	end
}

local cli = argparse("pesde-make-rbxm", "A simple pesde binary to make RBXM from pesde Roblox packages")
cli:argument("package", "pesde package name")
cli:option("--output -o", "RBXM output file. defaults to current {cwd}/{package_name}.rbxm")
cli:option("--provider -p", "Toolchain managing provider. if no provider is given, it will look for rojo in the current environment")
cli:action(function(args: {
	package: string,
	output: string?,
	provider: string?,
})
	local tempDir = dirs.createTempDir()
	local ok, err: string = pcall(function()
		local function exec(program: string, params: { string })
			local result = process.exec(program, params, { cwd = tempDir.path:toString() })
			if not result.ok then
				error(result.stderr)
			end
		end

		-- Write default pesde manifest
		local pesdeManifestPath = pathfs.FilePath.new(tempDir.path:join(DEFAULT_PESDE_PATH))
		pathfs.serializeFile(DEFAULT_PESDE_MANIFEST, pesdeManifestPath)

		-- Setup pesde project
		exec("pesde", { "add", args.package })
		exec("pesde", { "install" })

		-- Get and validate the package file
		local robloxPackagesDir = pathfs.DirectoryPath.fromExisting(tempDir.path:join("roblox_packages"))
		local addedPackageName = next(pathfs.deserializeFile(pesdeManifestPath))
		if not addedPackageName or type(addedPackageName) ~= "string" then
			error("The given package is not properly added to pesde manifest")
		end

		-- Write src/init.luau (the entry module)
		local packageLinkFile = pathfs.FilePath.fromExisting(robloxPackagesDir.path:join(addedPackageName):withExtension("luau"))
		local lines = packageLinkFile:readFile():split("\n")
		lines[1] = "local module = require(\"@self/roblox_packages/vide\")"
		pathfs.writeFileAll(tempDir.path:join("src"):join("init.luau"), table.concat(lines, "\n"))

		-- Write default rojo project for model build
		pathfs.serializeFile({
			name = addedPackageName,
			tree = {
				["$path"] = "src",
				roblox_packages = {
					["$path"] = "roblox_packages",
				},
			},
		}, tempDir.path:join("default.project.json"))

		-- Setup rojo and build into RBXM
		local function setupRojo()
			if not args.provider then
				return
			end
			local getRojo = getRojoByProvider[args.provider]
			if not getRojo then
				error(`Provider '{args.provider}' is not supported`)
			end
			getRojo({
				exec = exec,
			})
		end
		setupRojo()

		local result = process.exec("rojo", { "build", "-o", args.output or addedPackageName .. ".rbxm" })
		if not result.ok then
			error(result.stderr)
		end
	end)
	tempDir:removeDir()
	if not ok then
		error(err)
	end
end)

cli:parse()
