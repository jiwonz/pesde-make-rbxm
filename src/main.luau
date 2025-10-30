local argparse = require("../lune_packages/argparse")
local pathfs = require("../lune_packages/pathfs")
local dirs = require("../lune_packages/dirs")
local process = require("@lune/process")
local stdio = require("@lune/stdio")

-- TODO: Use tableHelper's extend instead in the future after it supports the newer luau require
local function extend<T, E>(target: { T }, extension: { E }): { T } & { E }
	local tbl = table.clone(target) :: { any }
	for _, v in extension do
		table.insert(tbl, v)
	end
	return tbl
end

local DEFAULT_PESDE_PATH = "pesde.toml"
local DEFAULT_PESDE_MANIFEST = table.freeze({
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
		scripts = { name = "jiwonz/pesde_scripts_rojo", version = "^0.2.0-rc.1", target = "lune" },
	},
	engines = {
		pesde = "^0.7.0",
		lune = "^0.10.2",
	},
	wally_indices = {
		default = "https://github.com/UpliftGames/wally-index",
	},
})
local ENTRY_MODULE_FILE_NAME = "lib.luau"

local cli = argparse("pesde-make-rbxm", "A simple pesde binary to make RBXM from pesde Roblox packages")
cli:argument("package", "pesde package name")
cli:option("--output -o", "RBXM output file. defaults to current {cwd}/{package_name}.rbxm")
cli:option(
	"--provider -p",
	"Toolchain managing provider. if no provider is given, it will look for rojo in the current environment"
)
cli:action(function(args: {
	package: string,
	output: string?,
	provider: string?,
})
	local tempDir = dirs.createTempDir()
	local ok, err: string = pcall(function()
		local function exec(program: string, params: { string })
			local result = process.exec(program, params, {
				cwd = tempDir.path:toString(),
			})
			if not result.ok then
				error(result.stderr)
			end
			return result
		end

		-- Write default pesde manifest
		local pesdeManifestPath = pathfs.FilePath.new(tempDir.path:join(DEFAULT_PESDE_PATH))
		pathfs.serializeFile(DEFAULT_PESDE_MANIFEST, pesdeManifestPath)

		-- Setup pesde project
		exec("pesde", { "add", args.package })
		exec("pesde", { "install" })

		-- Get and validate the package file
		local robloxPackagesDir = pathfs.DirectoryPath.fromExisting(tempDir.path:join("roblox_packages"))
		local addedPackageName = next(pathfs.deserializeFile(pesdeManifestPath).dependencies)
		if not addedPackageName or type(addedPackageName) ~= "string" then
			error("The given package is not properly added to pesde manifest")
		end

		-- Write src/init.luau (the entry module)
		local packageLinkFile =
			pathfs.FilePath.fromExisting(robloxPackagesDir.path:join(addedPackageName):withExtension("luau"))
		local lines = packageLinkFile:readFile():split("\n")
		lines[1] = 'local module = require("@self/roblox_packages/vide")'
		pathfs.FilePath.new(tempDir.path:join(ENTRY_MODULE_FILE_NAME)):withFileWritten(table.concat(lines, "\n"))

		-- Write default rojo project for model build
		pathfs.serializeFile({
			name = addedPackageName,
			tree = {
				["$path"] = ENTRY_MODULE_FILE_NAME,
				roblox_packages = {
					["$path"] = "roblox_packages",
				},
			},
		}, tempDir.path:join("default.project.json"))

		-- Setup rojo and build into RBXM
		local function rojoFromPesdeX(params: { string })
			exec("pesde", extend({ "x", "pesde/rojo", "--" }, params))
		end
		local rojoExecByProvider: { [string]: ((params: { string }) -> ())? } = {
			_ = function(params)
				print("info: no provider is given or not supported. fallbacks to default rojo program")
				-- selene: allow(shadowing)
				local ok, msg = pcall(exec, "rojo", params)
				if not ok then
					print(`default rojo program failure: {msg}\n\nfallbacks to 'pesde x'..`)
					rojoFromPesdeX(params)
				end
			end,
			mise = function(params)
				exec("mise", { "settings", "--local", "experimental=true" })
				exec("mise", { "trust", "mise.toml" })
				exec("mise", extend({ "x", "github:rojo-rbx/rojo", "--", "rojo" }, params))
			end,
			pesde = function(params)
				rojoFromPesdeX(params)
			end,
			rokit = function(params) -- not tested :(
				exec("rokit", { "init" })
				exec("rokit", { "add", "rojo" })
				exec("rokit", { "install" })
				exec("rojo", params)
			end,
			aftman = function(params) -- not tested :(
				exec("aftman", { "init" })
				exec("aftman", { "add", "rojo-rbx/rojo" })
				exec("aftman", { "install" })
				exec("rojo", params)
			end,
		}
		local rojoExec = rojoExecByProvider[args.provider or "_"]
		assert(rojoExec, "assertion failure. this is a bug")

		local outputFullPath = pathfs.absolute(args.output or addedPackageName .. ".rbxm"):toString()
		rojoExec({ "build", "-o", outputFullPath })

		print(
			stdio.color("green")
				.. `Successfully made {stdio.color("purple")}{args.package}{stdio.color("green")}'s RBXM into '{stdio.color(
					"cyan"
				)}{outputFullPath}{stdio.color("green")}'`
				.. stdio.color("reset")
		)
	end)
	tempDir:removeDir()
	if not ok then
		error(err)
	end
end)

cli:parse()
