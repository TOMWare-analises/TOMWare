#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Converte scripts PowerShell em ASCII puro para compatibilidade estrita com PS 5.1 no Windows."""
from pathlib import Path

root = Path(__file__).resolve().parent
repls = {
    "\u2014": "-",  # em-dash
    "\u2013": "-",  # en-dash
    "\u2018": "'",
    "\u2019": "'",
    "\u201c": '"',
    "\u201d": '"',
    "\ufeff": "",
    "á": "a", "à": "a", "ã": "a", "â": "a",
    "é": "e", "ê": "e",
    "í": "i",
    "ó": "o", "ô": "o", "õ": "o",
    "ú": "u",
    "ç": "c",
    "Á": "A", "À": "A", "Ã": "A", "Â": "A",
    "É": "E", "Ê": "E",
    "Í": "I",
    "Ó": "O", "Ô": "O", "Õ": "O",
    "Ú": "U",
    "Ç": "C",
}

for ps1 in root.rglob("*.ps1"):
    text = ps1.read_text(encoding="utf-8", errors="replace")
    for k, v in repls.items():
        text = text.replace(k, v)
    text = text.encode("ascii", errors="replace").decode("ascii")
    ps1.write_text(text, encoding="ascii")
    print(f"Sanitized: {ps1}")
