{
  description = "Nix flake for testing";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.11";

    outoftree = {
      url = "path:./pkgs";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, outoftree, ... }@inputs: let
    pkgs = nixpkgs.legacyPackages.x86_64-linux;
    inherit outoftree;
  in {
    devShells.x86_64-linux.default = pkgs.mkShell {
      buildInputs = [
        outoftree.pkgs.${pkgs.system}.python3Optimized
        outoftree.pkgs.${pkgs.system}.pyPkgs.cmake
        outoftree.pkgs.${pkgs.system}.pyPkgs.cython
        outoftree.pkgs.${pkgs.system}.pyPkgs.virtualenvwrapper
        outoftree.pkgs.${pkgs.system}.pyPkgs.setuptools
        outoftree.pkgs.${pkgs.system}.pyPkgs.readme-renderer

        pkgs.gnumake
        pkgs.wget
        pkgs.curl
        pkgs.openssh
        pkgs.git
        pkgs.bashInteractive

        pkgs.openssl
        pkgs.zlib
      ];
      shellHook = ''
        git submodule update --init --recursive
        cd /build
        python3 -m readme_renderer ./README.rst -o /tmp/README.html
        \rm ./ssh2/*.c
        python3 setup.py build_ext --inplace
        python3 -m venv ~/.py-venv/
        source ~/.py-venv/bin/activate
        pip install -e .[tests]
        pip install --upgrade pytest coveralls pytest-cov pytest-xdist paramiko > /dev/null
        py.test --cov ssh2 --cov-config .coveragerc

        echo "*********** Coverage ***********"
        coverage html
        coverage xml

        CODE_VALIDATION_PY_FILES="$(find ./ssh2 -type f | grep -E '\.py(x|)$' | grep -v 'tests/' | grep -v '\_version\.py')" # Ignore tests for now.
        BANDIT_REPORT=$(tempfile)
        PYLINT_REPORT=$(tempfile)
        SAFETY_REPORT=$(tempfile)
        echo "*********** Bandit ***********"
        bandit -c ./.bandit.yml -r $${CODE_VALIDATION_PY_FILES} 2>&1 > "$${BANDIT_REPORT}"
        cat "$${BANDIT_REPORT}"

        echo "*********** Pylint ***********"
        pylint $${CODE_VALIDATION_PY_FILES} 2>&1 > "$${PYLINT_REPORT}"
        cat "$${PYLINT_REPORT}"

        echo "*********** Safety ***********"
        safety scan 2>&1 > "$${SAFETY_REPORT}"
        cat "$${SAFETY_REPORT}"

        # pip install redssh[tests]
        # git clone https://github.com/Red-M/RedSSH.git /tmp/redssh
        # cp -r /tmp/redssh/tests ./tests
        # \rm -rf /tmp/redssh
      '';
    };
  };
}

