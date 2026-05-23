# surge-xt-for-rpi Debian package builder

Source: https://github.com/bwanab/surge-debian-package

Builds a `.deb` package of [Surge XT](https://surge-synthesizer.github.io) for Raspberry Pi (ARM64), from a surge source tree that has already been built. The default source location is `../surge`.

## Directory layout

```
.
├── copy-files.sh                          # build script
├── template/
│   ├── DEBIAN/
│   │   └── control                        # package metadata template
│   └── usr/share/
│       ├── doc/surge-xt-for-rpi/
│       │   ├── changelog.Debian           # edit this before each release
│       │   └── copyright                  # static DEP-5 copyright file
│       └── lintian/overrides/
│           └── surge-xt-for-rpi           # lintian overrides (static)
```

## Releasing a new version

### 0. Build Surge XT

The surge source tree must be built before running the packaging script. See the [Surge XT README](https://github.com/surge-synthesizer/surge) for build instructions. The default expected location for the source tree is `../surge`.

### 1. Update the changelog

Edit `template/usr/share/doc/surge-xt-for-rpi/changelog.Debian` and prepend a new entry:

```
surge-xt-for-rpi (1.5-1) unstable; urgency=low

  * Brief description of what changed.

 -- Bill Allen <pb@ballen.fastmail.fm>  Day, DD Mon YYYY HH:MM:SS +0000
```

The day-of-week must match the date or lintian will warn.

### 2. Run copy-files.sh

For a stable upstream release (source at `../surge`):

```bash
./copy-files.sh 1.5-1
```

For a pre-release git snapshot (appends `~gitYYYYMMDD` to the version automatically):

```bash
./copy-files.sh 1.5-1 --git
```

To use a source tree in a non-default location:

```bash
./copy-files.sh 1.5-1 --source ~/path/to/surge
./copy-files.sh 1.5-1 --git --source ~/path/to/surge
```

The script expects:
- Binaries in `<source>/build/surge_xt_products/`
- Data files in `<source>/resources/data/`

It will fail with a clear error if either directory is missing (i.e. the build hasn't been run yet).

The script:
- Creates the package directory `surge-xt-for-rpi_<version>/`
- Copies and strips the standalone binaries to `/usr/bin/`
- Copies and strips the CLAP plugins (plain shared objects) to `/usr/lib/clap/`
- Copies the VST3 bundles to `/usr/lib/vst3/` and strips the shared object inside each bundle
- Copies data files from the source tree to `/usr/share/surge-xt/`, removing any `.DS_Store` files
- Substitutes `@VERSION@` and `@INSTALLED_SIZE@` into the control file
- Compresses the changelog
- Sets ownership to `root:root`

### 3. Build and check the package

```bash
sudo dpkg-deb --build surge-xt-for-rpi_<version>
lintian surge-xt-for-rpi_<version>.deb
```

A clean lintian run produces no output and exits 0.

### 4. Install

```bash
sudo dpkg -i surge-xt-for-rpi_<version>.deb
```

## Lintian overrides

The following lintian tags are overridden because they are expected and not fixable without upstream changes:

- `embedded-library` — libpng and tinyxml are statically linked by upstream
- `hardening-no-pie` — upstream build does not enable PIE
- `no-manual-page` — no man pages are provided by upstream
