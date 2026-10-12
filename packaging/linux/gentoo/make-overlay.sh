#!/usr/bin/env bash
# Assemble a Gentoo overlay holding app-accessibility/talkies (source) and
# app-accessibility/talkies-bin (prebuilt), with Manifests, from the recipes
# package.sh rendered.
#
#   make-overlay.sh <recipes dir> <distfiles dir> <overlay dir>
#
# Every distfile named in SRC_URI must be in <distfiles dir> under its Gentoo
# name; missing ones are downloaded from their SRC_URI (so pre-seed whatever
# is not published yet, e.g. a release's own assets).
set -euo pipefail

RECIPES="$(cd "${1:?recipes dir}" && pwd)"
DISTFILES="${2:?distfiles dir}"
OVERLAY="${3:?overlay dir}"
CATEGORY=app-accessibility
mkdir -p "${DISTFILES}" "${OVERLAY}/profiles" "${OVERLAY}/metadata"
DISTFILES="$(cd "${DISTFILES}" && pwd)"

echo talkies > "${OVERLAY}/profiles/repo_name"
printf 'masters = gentoo\nthin-manifests = true\nsign-manifests = false\n' > "${OVERLAY}/metadata/layout.conf"

# Print "<distfile> <url>" for every SRC_URI entry, by evaluating the ebuild's
# global scope the way Portage would (inherit is a no-op here).
src_uris() { # <ebuild> <PN> <PV>
    (
        # shellcheck disable=SC2317,SC2034 # read by the sourced ebuild
        inherit() { :; }
        # shellcheck disable=SC2034 # read by the sourced ebuild
        PN="$2" PV="$3" P="$2-$3" WORKDIR=/nonexistent
        # shellcheck disable=SC1090
        source "$1"
        # shellcheck disable=SC2086 # split SRC_URI into tokens
        set -- ${SRC_URI}
        while (($#)); do
            url="$1" name="${1##*/}"
            shift
            if [[ "${1:-}" == "->" ]]; then name="$2" && shift 2; fi
            echo "${name} ${url}"
        done
    )
}

shopt -s nullglob
ebuilds=("${RECIPES}"/*.ebuild)
shopt -u nullglob
((${#ebuilds[@]})) || { echo "No ebuilds in ${RECIPES}" >&2; exit 1; }

for ebuild in "${ebuilds[@]}"; do
    file="$(basename "${ebuild}" .ebuild)"
    pv="${file##*-}"
    pn="${file%-"${pv}"}"
    pkg="${OVERLAY}/${CATEGORY}/${pn}"
    mkdir -p "${pkg}"
    cp "${ebuild}" "${pkg}/"
    # The prebuilt package has no build-time CPU choice.
    if [[ "${pn}" == *-bin ]]; then
        grep -v '<flag name="native">' "${RECIPES}/metadata.xml" > "${pkg}/metadata.xml"
    else
        cp "${RECIPES}/metadata.xml" "${pkg}/metadata.xml"
    fi
    : > "${pkg}/Manifest"
    while read -r name url; do
        if [[ ! -f "${DISTFILES}/${name}" ]]; then
            echo "Fetching ${name}"
            curl -fsSL --retry 3 -o "${DISTFILES}/${name}.part" "${url}"
            mv "${DISTFILES}/${name}.part" "${DISTFILES}/${name}"
        fi
        f="${DISTFILES}/${name}"
        printf 'DIST %s %s BLAKE2B %s SHA512 %s\n' "${name}" "$(stat -c %s "${f}")" \
            "$(b2sum "${f}" | cut -d' ' -f1)" "$(sha512sum "${f}" | cut -d' ' -f1)" >> "${pkg}/Manifest"
    done < <(src_uris "${ebuild}" "${pn}" "${pv}")
    echo "${CATEGORY}/${pn}-${pv}: $(wc -l < "${pkg}/Manifest") distfiles"
done
