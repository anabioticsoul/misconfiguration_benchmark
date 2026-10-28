#!/usr/bin/env bash
set -euo pipefail
module=/etc/apache2/mods-enabled/authz_core.load
test -f "$module"
sed -i 's/^LoadModule authz_core_module /#LoadModule authz_core_module /' "$module"
test "$(head -n 1 "$module")" = '#LoadModule authz_core_module /usr/lib/apache2/modules/mod_authz_core.so'
