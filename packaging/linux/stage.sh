#!/usr/bin/env bash
# Lay out a built Talkies into an FHS tree under DESTDIR. Every Linux
# deliverable (tarball, .deb, .rpm, Arch, Gentoo) is made from this tree:
#
#   /usr/bin/talkies -> ../lib/talkies/talkies
#   /usr/lib/talkies/talkies             (RUNPATH $ORIGIN/lib)
#   /usr/lib/talkies/lib/*.so*           Talkies UI/native + bundled whisper/llama/ggml
#   /usr/share/applications, metainfo, icons/hicolor, doc/talkies
#   /usr/lib/udev/rules.d/70-talkies-uinput.rules
#
# Inputs (environment):
#   DESTDIR         staging root (required)
#   ZIG_OUT         `zig build --prefix` output (default linux/zig-out)
#   BUNDLE_NATIVE   1 = copy whisper/llama/ggml from NATIVE_LIBDIR (default 1);
#                   0 = rely on system-wide whisper.cpp / llama.cpp
#   NATIVE_LIBDIR   where build-native-deps.sh installed them (default /usr/local/lib)
#   STRIP_DEBUG     1 = strip debug info (default); 0 = leave it to the distro
#                   tooling (Gentoo's splitdebug / strip)
#   ALLOW_NATIVE_CPU 1 = skip the portable-CPU check (local or -march=native builds)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
DESTDIR="${DESTDIR:?Set DESTDIR to the staging root}"
ZIG_OUT="${ZIG_OUT:-${ROOT}/linux/zig-out}"
BUNDLE_NATIVE="${BUNDLE_NATIVE:-1}"
NATIVE_LIBDIR="${NATIVE_LIBDIR:-/usr/local/lib}"

app="${DESTDIR}/usr/lib/talkies"
share="${DESTDIR}/usr/share"
install -d "${app}/lib" "${DESTDIR}/usr/bin" "${share}/applications" "${share}/metainfo" \
    "${share}/doc/talkies/licenses" "${share}/talkies" "${DESTDIR}/usr/lib/udev/rules.d"

install -m 0755 "${ZIG_OUT}/bin/talkies" "${app}/talkies"
ln -sfn ../lib/talkies/talkies "${DESTDIR}/usr/bin/talkies"
cp -P "${ZIG_OUT}"/lib/libtalkies-*.so.* "${app}/lib/"

if [[ "${BUNDLE_NATIVE}" == 1 ]]; then
    shopt -s nullglob
    native=("${NATIVE_LIBDIR}"/libwhisper.so.* "${NATIVE_LIBDIR}"/libllama.so.* "${NATIVE_LIBDIR}"/libggml*.so*)
    shopt -u nullglob
    for want in libwhisper libllama libggml.so libggml-base libggml-cpu; do
        if ! printf '%s\n' "${native[@]}" | grep -q "/${want}"; then
            echo "Missing bundled runtime ${want} in ${NATIVE_LIBDIR} (run build-native-deps.sh)" >&2
            exit 1
        fi
    done
    cp -P "${native[@]}" "${app}/lib/"
fi

# Talkies' own code must target a portable CPU (zig build -Dcpu=x86_64_v2):
# AVX/AVX-512 registers mean it was built for the build machine and would die
# with SIGILL on older CPUs. (ggml checks its own CPU features at runtime.)
if [[ "${ALLOW_NATIVE_CPU:-0}" != 1 ]] && command -v objdump >/dev/null; then
    for f in "${app}/talkies" "${app}"/lib/libtalkies-*.so.*.*; do
        # grep reads everything (no -q): an early exit would SIGPIPE objdump under pipefail.
        if objdump -d "${f}" | grep -E '%[yz]mm' >/dev/null; then
            echo "$(basename "${f}") uses AVX instructions; rebuild with -Dcpu=x86_64_v2 (or set ALLOW_NATIVE_CPU=1 for a local build)." >&2
            exit 1
        fi
    done
fi

# Strip debug info from what we ship (sizes drop ~4x); keep symbols for backtraces.
if [[ "${STRIP_DEBUG:-1}" == 1 ]] && command -v strip >/dev/null; then
    find "${app}" -type f \( -name talkies -o -name '*.so*' \) -exec strip --strip-debug {} +
fi

cp -r "${ZIG_OUT}/share/icons" "${share}/"
install -m 0644 "${ROOT}/linux/data/app.talkies.Talkies.desktop" "${share}/applications/"
install -m 0644 "${ROOT}/linux/data/app.talkies.Talkies.metainfo.xml" "${share}/metainfo/"
install -m 0644 "${ROOT}/linux/data/70-talkies-uinput.rules" "${DESTDIR}/usr/lib/udev/rules.d/"
install -m 0755 "${ROOT}/linux/scripts/talkies-hotkey.sh" "${share}/talkies/talkies-hotkey.sh"
install -m 0644 "${ROOT}/linux/hyprland-overlay-rules.conf" "${share}/talkies/hyprland-rules.conf"

install -m 0644 "${ROOT}/LICENSE" "${share}/doc/talkies/LICENSE"
install -m 0644 "${ROOT}/linux/README.md" "${share}/doc/talkies/README.md"
install -m 0644 "${ROOT}/packaging/shared/licenses/libfvad-BSD-3-Clause.txt" "${share}/doc/talkies/licenses/"
if [[ "${BUNDLE_NATIVE}" == 1 ]]; then
    install -m 0644 "${ROOT}/packaging/shared/licenses/whisper.cpp-MIT.txt" "${share}/doc/talkies/licenses/"
    install -m 0644 "${ROOT}/packaging/shared/licenses/llama.cpp-MIT.txt" "${share}/doc/talkies/licenses/"
fi

# The staged binary must resolve every library from the tree or the base system.
if ldd "${app}/talkies" | grep -F 'not found'; then
    echo "Staged Talkies has unresolved libraries (see above)." >&2
    exit 1
fi
"${app}/talkies" --version
echo "Staged Talkies into ${DESTDIR}"
