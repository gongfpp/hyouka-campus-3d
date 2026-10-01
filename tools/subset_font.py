#!/usr/bin/env python3
"""Rebuild the checked-in OFL Noto Sans CJK SC UI subset after changing Chinese UI text.
Requires fontTools (from PyPI). Supply a NotoSansCJK-Regular.ttc as the sole argument.
"""
from pathlib import Path
import sys
from fontTools import subset
from fontTools.ttLib import TTFont
root = Path(__file__).resolve().parents[1]
source = Path(sys.argv[1])
font = TTFont(source, fontNumber=2)
options = subset.Options()
options.name_IDs = ['*']
subsetter = subset.Subsetter(options=options)
text = ''.join(path.read_text() for path in (root / 'scripts').glob('*.gd'))
text += ''.join(map(chr, range(32, 127))) + '◇↗✓●○冰菓：放课后的神山'
subsetter.populate(text=text)
subsetter.subset(font)
font.save(root / 'assets/fonts/KamiyamaSans.otf')
