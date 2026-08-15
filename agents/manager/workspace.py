"""Path-safe file operations for agent build workspaces."""

from __future__ import annotations

from pathlib import Path, PurePosixPath


class WorkspaceFiles:
    def __init__(self, root: Path) -> None:
        self.root = root.resolve()

    def read(self, relative_path: str) -> str:
        return self._resolve(relative_path).read_text(encoding="utf-8")

    def write(self, relative_path: str, content: str) -> None:
        path = self._resolve(relative_path)
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(content, encoding="utf-8")

    def replace(self, relative_path: str, old_text: str, new_text: str) -> None:
        path = self._resolve(relative_path)
        content = path.read_text(encoding="utf-8")
        occurrences = content.count(old_text)
        if occurrences != 1:
            raise ValueError(
                f"Expected exactly one old_text occurrence, found {occurrences}"
            )
        path.write_text(content.replace(old_text, new_text, 1), encoding="utf-8")

    def _resolve(self, relative_path: str) -> Path:
        normalized = PurePosixPath(relative_path)
        if normalized.is_absolute() or ".." in normalized.parts:
            raise ValueError(f"Workspace path must be relative and contained: {relative_path}")
        path = (self.root / normalized.as_posix()).resolve()
        if path != self.root and self.root not in path.parents:
            raise ValueError(f"Workspace path escapes root: {relative_path}")
        return path
