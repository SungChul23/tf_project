#!/usr/bin/env python3
import os
import string
import sys
from pathlib import Path

required = ["APP_NAMESPACE", "WEB_IMAGE", "WAS_IMAGE"]
missing = [name for name in required if not os.getenv(name)]
if missing:
    raise SystemExit(f"Missing environment variables: {', '.join(missing)}")

template_path = Path(__file__).parent / "k8s" / "app.yaml.tpl"
template = string.Template(template_path.read_text(encoding="utf-8"))
sys.stdout.write(template.substitute(os.environ))