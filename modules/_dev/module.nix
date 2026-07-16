# Dev partition module — full dev tooling + per-backend test checks.
#
# Each supported backend gets its own check derivation, run in parallel.
# An aggregation check gates them all for `nix flake check`.
#
# Usage:
#   nix flake check              # treefmt + all backend tests (parallel)
#   nix fmt                      # auto-format
#   nix develop                  # shell with nix-unit
#   nix build .#nix-lib-docs
{ inputs, config, ... }:
{
  imports = [
    ../nix-lib/_default.nix
    inputs.treefmt-nix.flakeModule
    # Declare flake.tests as mergeable (multiple modules contribute tests)
    ({ lib, ... }: {
      options.flake.tests = lib.mkOption {
        type = lib.types.attrsOf lib.types.anything;
        default = { };
      };
    })

    # Full integration examples — creates nixosConfigurations,
    # homeConfigurations, etc. for BDD + unit tests to validate.
    ../../examples/full-integration.nix

    # BDD tests — pure Nix assertions about library structure
    ../../tests/bdd/libDef.nix
    ../../tests/bdd/collectors.nix

    # Scenario tests — mkFlake, mkLib, backend format checks
    ./scenario-checks.nix
  ];

  perSystem =
    { system, lib, ... }:
    let
      pkgs = inputs.nixpkgs.legacyPackages.${system};

      # ── Test data ──────────────────────────────────────────────────
      # All { expr, expected } tests from flake.tests (BDD + scenario + auto-generated).
      # Filtered to JSON-serializable values only.
      isJsonSafe =
        v:
        builtins.isInt v
        || builtins.isBool v
        || builtins.isString v
        || builtins.isFloat v
        || v == null
        || (builtins.isList v && builtins.all isJsonSafe v)
        || (builtins.isAttrs v && !(v ? outPath) && builtins.all isJsonSafe (builtins.attrValues v));

      allTests = lib.filterAttrs (
        _: test: test ? expr && test ? expected && isJsonSafe test.expr && isJsonSafe test.expected
      ) (config.flake.tests or { });
      testCount = builtins.length (builtins.attrNames allTests);

      testsJson = pkgs.writeText "tests.json" (builtins.toJSON allTests);

      # ── Per-backend checks ─────────────────────────────────────────

      # 1. nix-unit: real CLI via JSON serialization
      check-nix-unit =
        pkgs.runCommand "check-nix-unit"
          {
            nativeBuildInputs = [
              inputs.nix-unit.packages.${system}.default
              pkgs.nix
            ];
          }
          ''
            export HOME=$(mktemp -d)
            echo "nix-unit: running ${toString testCount} tests..."
            nix-unit --expr "builtins.fromJSON (builtins.readFile ${testsJson})"
            echo "nix-unit: ${toString testCount} tests passed"
            touch $out
          '';

      # 2. runTests: pure Nix lib.debug.runTests (eval-time)
      runTestsResults = lib.debug.runTests allTests;
      check-runTests =
        if runTestsResults != [ ] then
          throw "runTests: ${toString (builtins.length runTestsResults)} failures: ${
            builtins.toJSON (map (f: f.name) runTestsResults)
          }"
        else
          pkgs.runCommand "check-runTests" { } ''
            echo "runTests: ${toString testCount} tests passed"
            touch $out
          '';

      # 3. nix-tests: real CLI with test file
      nixTestsFile = pkgs.writeText "nix-tests-suite.nix" ''
        let
          tests = builtins.fromJSON (builtins.readFile ${testsJson});
        in
        {
          "nix-lib" = helpers:
            builtins.mapAttrs (name: test:
              helpers.isEq test.expr test.expected
            ) tests;
        }
      '';
      # 4. nixtest (Jetify): pure Nix eval-time, values stringified as JSON
      nixtestLib = import "${inputs.nixtest}/src/nixtest.nix";
      nixtestTests = builtins.map (name: {
        inherit name;
        actual = builtins.toJSON allTests.${name}.expr;
        expected = builtins.toJSON allTests.${name}.expected;
      }) (builtins.attrNames allTests);
      nixtestResult = nixtestLib.assertTests (nixtestLib.runTests nixtestTests);
      check-nixtest =
        if !(lib.hasInfix "PASS" nixtestResult) then
          throw "nixtest: ${nixtestResult}"
        else
          pkgs.runCommand "check-nixtest" { } ''
            echo "nixtest: ${toString testCount} tests passed"
            touch $out
          '';

      # 5. namaka: eval-time via namaka.lib.load with generated test dir + snapshots.
      # Each test becomes a dir with expr.nix reading its value from a shared JSON file.
      namakaAllData = pkgs.writeText "namaka-data.json" (builtins.toJSON allTests);
      namakaTestDir =
        let
          testNames = builtins.attrNames allTests;
          safeName = name: builtins.replaceStrings [ " " "'" "\"" "/" ] [ "_" "" "" "_" ] name;
          mkTestDir =
            name:
            let
              sn = safeName name;
              test = allTests.${name};
              # Write expr.nix that reads the shared JSON and extracts this test's expr
              exprNix = pkgs.writeText "${sn}-expr.nix" ''
                let
                  all = builtins.fromJSON (builtins.readFile ${namakaAllData});
                in
                all.${builtins.toJSON name}.expr
              '';
              snapshot = pkgs.writeText "${sn}-snapshot" "#json\n${builtins.toJSON test.expected}";
            in
            ''
              mkdir -p $out/${sn}
              cp ${exprNix} $out/${sn}/expr.nix
              cp ${snapshot} $out/_snapshots/${sn}
            '';
        in
        pkgs.runCommand "namaka-tests-src" { } ''
          mkdir -p $out/_snapshots
          ${builtins.concatStringsSep "\n" (builtins.map mkTestDir testNames)}
        '';
      # namaka.lib.load throws at eval time if any snapshot mismatches.
      check-namaka =
        assert inputs.namaka.lib.load { src = namakaTestDir; } == { };
        pkgs.runCommand "check-namaka" { } ''
          echo "namaka: ${toString testCount} snapshot tests passed"
          touch $out
        '';

      # 6. nixt: write describe/it test file, run nixt CLI
      nixtTestFile = pkgs.writeText "nixt-suite.nix" ''
        { describe, it, ... }:
        let
          tests = builtins.fromJSON (builtins.readFile ${testsJson});
          names = builtins.attrNames tests;
        in
        [
          (describe "nix-lib" (builtins.map (name:
            it name (tests.''${name}.expr == tests.''${name}.expected)
          ) names))
        ]
      '';
      check-nixt =
        pkgs.runCommand "check-nixt"
          {
            nativeBuildInputs = [
              inputs.nixt.packages.${system}.default
              pkgs.nix
            ];
          }
          ''
            export HOME=$(mktemp -d)
            mkdir -p $HOME/tests
            cp ${nixtTestFile} $HOME/tests/test.nix
            echo "nixt: running ${toString testCount} tests..."
            nixt $HOME/tests/
            echo "nixt: passed"
            touch $out
          '';

      # 7. nix-tests: real CLI with test file
      check-nix-tests =
        pkgs.runCommand "check-nix-tests"
          {
            nativeBuildInputs = [
              inputs.nix-tests.packages.${system}.default
              pkgs.nix
            ];
          }
          ''
            export HOME=$(mktemp -d)
            echo "nix-tests: running ${toString testCount} tests..."
            nix-tests ${nixTestsFile}
            echo "nix-tests: passed"
            touch $out
          '';
    in
    {
      _module.args.pkgs = pkgs;

      treefmt = {
        projectRootFile = "flake.nix";
        programs.nixfmt.enable = true;
      };

      # All backends tested in parallel via a single aggregation derivation.
      checks.tests = pkgs.runCommand "tests" { } ''
        mkdir -p $out
        ln -s ${check-nix-unit} $out/nix-unit
        ln -s ${check-runTests} $out/runTests
        ln -s ${check-nix-tests} $out/nix-tests
        ln -s ${check-nixtest} $out/nixtest
        ln -s ${check-namaka} $out/namaka
        ln -s ${check-nixt} $out/nixt
      '';

      devShells.default = pkgs.mkShell {
        packages = [
          inputs.nix-unit.packages.${system}.default
          inputs.nix-tests.packages.${system}.default
        ];
      };
    };
}
