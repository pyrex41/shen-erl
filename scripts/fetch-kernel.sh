#!/bin/sh
# Fetch the pinned S42 kernel distribution into DESTDIR (default: S42).
#
# Primary source: the canonical mirror pyrex41/shen-upstream at the peeled
# commit of tag s42-pristine-20260825, as a checksum-pinned GitHub tarball.
# Fallback: the shenlanguage.org upload, accepted only when its SHA-256
# matches the pinned value.  Nothing is extracted unless a checksum matches,
# so an upstream re-upload fails loudly instead of changing the kernel.
#
# All pins are passed in by the Makefile; see KERNEL.md.
set -eu

: "${MIRROR_URL:?}" "${MIRROR_ARCHIVE:?}" "${MIRROR_SHA256:?}"
: "${UPSTREAM_URL:?}" "${UPSTREAM_ARCHIVE:?}" "${UPSTREAM_SHA256:?}"
DESTDIR=${DESTDIR:-S42}

verify() {
  # verify FILE SHA256
  [ -f "$1" ] && printf '%s  %s\n' "$2" "$1" | shasum -a 256 -c >/dev/null 2>&1
}

fetch() {
  # fetch URL FILE SHA256: reuse a verified local copy, else download.
  if verify "$2" "$3"; then
    return 0
  fi
  rm -f "$2"
  if curl -fsSL "$1" -o "$2.part"; then
    mv "$2.part" "$2"
    if verify "$2" "$3"; then
      return 0
    fi
    echo "fetch-kernel: checksum mismatch for $1" >&2
    printf '  expected %s\n  got      ' "$3" >&2
    shasum -a 256 "$2" | cut -d' ' -f1 >&2
    rm -f "$2"
  else
    rm -f "$2.part"
    echo "fetch-kernel: download failed: $1" >&2
  fi
  return 1
}

rm -rf "$DESTDIR"

if fetch "$MIRROR_URL" "$MIRROR_ARCHIVE" "$MIRROR_SHA256"; then
  echo "fetch-kernel: using mirror $MIRROR_URL"
  mkdir -p "$DESTDIR"
  tar xzf "$MIRROR_ARCHIVE" -C "$DESTDIR" --strip-components=1
elif fetch "$UPSTREAM_URL" "$UPSTREAM_ARCHIVE" "$UPSTREAM_SHA256"; then
  echo "fetch-kernel: mirror unavailable; using verified upstream $UPSTREAM_URL"
  tmp=$(mktemp -d)
  unzip -qo "$UPSTREAM_ARCHIVE" -d "$tmp"
  mv "$tmp/S42" "$DESTDIR"
  rm -rf "$tmp"
else
  echo "fetch-kernel: no source matched its pinned checksum" >&2
  exit 1
fi

test -f "$DESTDIR/KLambda/core.kl"
test -d "$DESTDIR/Test Programs"
touch "$DESTDIR"
