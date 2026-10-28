#!/usr/bin/env bash
set -euo pipefail
install -d /opt/eclipse-workspace/.metadata/.plugins/org.eclipse.debug.ui /opt/eclipse-workspace/.metadata/.plugins/org.eclipse.debug.core/.launches /usr/local/bin
install -m 0755 /opt/eclipse-config-check /usr/local/bin/eclipse-config-check
rm -f /opt/eclipse-config-check
cat > /opt/eclipse-workspace/.metadata/.plugins/org.eclipse.debug.ui/org.eclipse.debug.ui.prefs <<'EOF'
filterDeletedProjects=false
EOF
cat > /opt/eclipse-workspace/.metadata/.plugins/org.eclipse.debug.core/.launches/Equivalence_Checker.launch <<'EOF'
<launchConfiguration type="org.eclipse.jdt.launching.localJavaApplication">
  <stringAttribute key="org.eclipse.jdt.launching.PROJECT_ATTR" value="equivalence-project"/>
  <stringAttribute key="org.eclipse.debug.core.LABEL" value="Equivalence Checker"/>
</launchConfiguration>
EOF
