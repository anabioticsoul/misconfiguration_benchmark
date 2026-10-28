#!/usr/bin/env bash
set -euo pipefail
patch_file="$(cd "$(dirname "$1")" && pwd)/$(basename "$1")"
script_dir="$(cd "$(dirname "$0")" && pwd)"
image="${2:-cb128:latest}"
root="$(mktemp -d)"
cleanup() { rm -rf "$root"; }
trap cleanup EXIT
cid=$(docker create "$image")
mkdir -p "$root/etc/apparmor.d"
docker cp "$cid:/etc/apparmor.d/usr.sbin.mysqld" "$root/etc/apparmor.d/usr.sbin.mysqld"
docker rm "$cid" >/dev/null
git -C "$root" init -q
git -C "$root" config user.email evaluator@example.invalid
git -C "$root" config user.name evaluator
git -C "$root" add etc
git -C "$root" commit -qm baseline
( cd "$root" && git apply --unsafe-paths "$patch_file" )
changed=$(git -C "$root" diff --name-only)
test "$changed" = "etc/apparmor.d/usr.sbin.mysqld"
grep -F '/srv/mysql/pids/mysqld-myDB.pid w,' "$root/etc/apparmor.d/usr.sbin.mysqld" >/dev/null
grep -F '/srv/mysql/sockets/mysql-myDB.sock w,' "$root/etc/apparmor.d/usr.sbin.mysqld" >/dev/null
cid=$(docker create "$image")
docker cp "$root/etc/apparmor.d/usr.sbin.mysqld" "$cid:/etc/apparmor.d/usr.sbin.mysqld"
docker start "$cid" >/dev/null
trap 'docker rm -f "$cid" >/dev/null 2>&1 || true; cleanup' EXIT
for _ in $(seq 1 30); do docker exec "$cid" test -f /etc/apparmor.d/usr.sbin.mysqld && break; sleep 1; done
docker exec "$cid" bash -lc 'bash -s' < "$script_dir/f2p.sh"
docker exec "$cid" bash -lc 'bash -s' < "$script_dir/p2p.sh"
