{
  mkShell,
  callPackage,
  androidenv,
  google-chrome,
  jdk21,
  just,
  yj,
  writeShellApplication,
  git,
  coreutils,
  lua,
}:
let
  mainPkg = callPackage ./package.nix { };

  myLua = lua.withPackages (ps: [
    ps.luafilesystem
  ]);

  androidComposition = androidenv.composeAndroidPackages {
    platformVersions = [ "36" ];
    buildToolsVersions = [ "36.0.0" ];
    platformToolsVersion = "37.0.1";
    cmdLineToolsVersion = "22.0";
    includeNDK = true;
    ndkVersions = [ "28.2.13676358" ];

    abiVersions = [
      "armeabi-v7a"
      "arm64-v8a"
    ];

    extraLicenses = [
      "android-sdk-preview-license"
      "android-googletv-license"
      "android-sdk-arm-dbt-license"
      "google-gdk-license"
      "intel-android-extra-license"
      "intel-android-sysimage-license"
      "mips-android-sysimage-license"
      "android-googlexr-license"
    ];
  };

  androidSdk = androidComposition.androidsdk;
in
mkShell {
  inputsFrom = [ mainPkg ];

  packages =
    let
      scripts = {
        mycommit = writeShellApplication {
          name = "mycommit";

          runtimeInputs = [
            git
            coreutils
            myLua
          ];

          text = /* bash */ ''
            TMP_DIR="temp"
            mkdir -p "$TMP_DIR"

            echo "Saving staged changes to $TMP_DIR/staged.diff..."
            git diff --staged > "$TMP_DIR/staged.diff"

            echo "Gathering commit history to $TMP_DIR/commits.log..."
            git log > "$TMP_DIR/commits.log"

            echo "Generating directory structure to $TMP_DIR/tree.log..."

            lua - "$TMP_DIR/tree.log" <<'LUA'
              local lfs = require("lfs")

              local output = arg[1]
              local root = lfs.currentdir()

              -- Root-level directories to collapse even if they are NOT gitignored.
              local collapse = {
                android = true,
                ios = true,
                linux = true,
                macos = true,
                web = true,
                windows = true,
              }

              -- Get root-level paths ignored by Git.
              local gitignored = {}

              local git = assert(io.popen(
                "git status --ignored --short --untracked-files=all"
              ))

              for line in git:lines() do
                if line:sub(1, 3) == "!! " then
                  local path = line:sub(4)
                  path = path:gsub("/$", "")

                  -- Take the first path component.
                  --
                  -- For example:
                  --   .direnv/bin/foo
                  -- becomes:
                  --   .direnv
                  --
                  -- This is necessary because Git may report the contents of
                  -- an ignored directory instead of the directory itself.
                  local root_name = path:match("^([^/]+)")

                  if root_name then
                    gitignored[root_name] = true
                  end
                end
              end

              git:close()

              local function is_directory(path)
                return lfs.attributes(path, "mode") == "directory"
              end

              local function should_collapse(name)
                return collapse[name] or gitignored[name]
              end

              local function get_entries(path)
                local directories = {}
                local files = {}

                for name in lfs.dir(path) do
                  if name ~= "."
                     and name ~= ".."
                     and name ~= ".git"
                     and name ~= "temp"
                  then
                    local full_path = path .. "/" .. name

                    if is_directory(full_path) then
                      table.insert(directories, name)
                    else
                      table.insert(files, name)
                    end
                  end
                end

                table.sort(directories, function(a, b)
                  return a:lower() < b:lower()
                end)

                table.sort(files, function(a, b)
                  return a:lower() < b:lower()
                end)

                for _, name in ipairs(files) do
                  table.insert(directories, name)
                end

                return directories
              end

              local function render(file, path, prefix, is_root)
                local entries = get_entries(path)

                for index, name in ipairs(entries) do
                  local last = index == #entries
                  local branch = last and "└── " or "├── "

                  file:write(prefix .. branch .. name .. "\n")

                  local full_path = path .. "/" .. name
                  local directory = is_directory(full_path)

                  if directory then
                    local child_prefix =
                      prefix .. (last and "    " or "│   ")

                    if is_root and should_collapse(name) then
                      file:write(child_prefix .. "└── ...\n")
                    else
                      render(file, full_path, child_prefix, false)
                    end
                  end
                end
              end

              local file = assert(io.open(output, "w"))

              file:write(root:match("([^/]+)$") .. "\n")
              render(file, root, "", true)

              file:close()
            LUA

            echo "All information has been saved to $PWD/$TMP_DIR."
          '';
        };
      };
    in
    [
      google-chrome
      jdk21
      androidSdk
      just
      yj
    ]
    ++ builtins.attrValues scripts;

  ANDROID_HOME = "${androidSdk}/libexec/android-sdk";
  ANDROID_SDK_ROOT = "${androidSdk}/libexec/android-sdk";
}
