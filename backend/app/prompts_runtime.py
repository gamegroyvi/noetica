"""Helpers for the universal `/tools/run` endpoint.

Renders a user-authored prompt template against form inputs and
augments it with the response-shape contract the LLM must follow. We
purposely do NOT use Python `str.format` — that would let any user
input string introduce new placeholders or invoke format spec tricks
like `{0:!r}`. Instead we extract a fixed allowlist of `{key}`
placeholders from the template and substitute them with `str(value)`,
escaping any `{}` that appear in user values themselves.
"""

from __future__ import annotations

import re

# A `{key}` placeholder. Keys are the same ids used by
# `GeneratorInputField.id` on the client (a-z, 0-9, underscore). We
# accept dash too because the manifest schema allows ids like
# `axis-id`. No spaces, no nested braces, no format spec.
_PLACEHOLDER = re.compile(r"\{([A-Za-z0-9_\-]+)\}")


def render_template(
    template: str,
    inputs: dict[str, object],
) -> str:
    """Substitute `{key}` markers in `template` from `inputs`.

    Unknown placeholders raise — the route turns this into a 422 so
    the author sees exactly which placeholder they typo'd. Values are
    coerced to `str()` and any `{}` characters in the resulting string
    are stripped to make sure a sneaky user-supplied value can't
    introduce a new placeholder downstream (defense-in-depth — the
    template is already user-owned, but a manifest run might one day
    relay another user's input).
    """

    def _repl(match: re.Match[str]) -> str:
        key = match.group(1)
        if key not in inputs:
            raise KeyError(key)
        raw = inputs[key]
        if raw is None:
            return ""
        if isinstance(raw, bool):
            # bool first because `bool` is a subclass of `int` and
            # we want "Да"/"Нет"-style language tags rather than 1/0.
            return "true" if raw else "false"
        text = str(raw)
        # Strip nested braces. Authors don't get to inject placeholders
        # via input values.
        return text.replace("{", "").replace("}", "")

    return _PLACEHOLDER.sub(_repl, template)


# JSON schema we ask the LLM to follow. Hard-coded so all user tools
# share the same response shape — the client's import logic depends on
# it. Authors don't get to redefine the wire contract.
_RESPONSE_SCHEMA_RU = (
    'СТРОГО следуй этой JSON-схеме:\n'
    '{\n'
    '  "summary": "1–2 предложения, что сгенерировано (опционально)",\n'
    '  "items": [\n'
    '    {\n'
    '      "title": "≤ 120 символов, что нужно сделать",\n'
    '      "body": "опционально, ≤ 2000 символов, детали",\n'
    '      "due_offset_days": "опционально, целое 0..365 — '
    'через сколько дней (0=сегодня)"\n'
    '    }\n'
    '  ]\n'
    '}'
)


def schema_addendum(max_items: int) -> str:
    """Schema instructions appended to every system prompt.

    Adding it server-side means manifest authors don't have to
    remember to write the schema themselves, AND the client's parser
    doesn't have to negotiate per-manifest shapes. One contract for
    every user-authored tool.
    """
    return (
        f"\n\nВерни JSON-объект (без markdown-обёрток). "
        f"Массив `items` должен содержать НЕ БОЛЕЕ {max_items} элементов.\n\n"
        f"{_RESPONSE_SCHEMA_RU}"
    )
