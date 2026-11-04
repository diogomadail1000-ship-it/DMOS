#!/usr/bin/env python3
"""Junta as medições de medir.sh e escreve video/desempenho-dados.js para o vídeo comparativo.

Uso: python3 video/medicoes-para-video.py "4 GB de RAM, 2 CPUs, QEMU/KVM" medicoes.jsonl [mais.jsonl ...]
O primeiro argumento descreve as condições do teste e aparece no vídeo.
Para cada distribuição usa a mediana das medições (corra medir.sh pelo menos três vezes em cada uma).
"""
import json
import statistics
import sys
from pathlib import Path

conditions, files = sys.argv[1], sys.argv[2:]
if not files:
    sys.exit(__doc__)

runs = {}
for f in files:
    for line in Path(f).read_text(encoding="utf-8").splitlines():
        if line.strip():
            row = json.loads(line)
            runs.setdefault(row["name"], []).append(row)

distros = []
for name, rows in runs.items():
    def med(key):
        values = [r[key] for r in rows if r.get(key) is not None]
        return round(statistics.median(values), 1) if values else None
    distros.append({"name": name, "runs": len(rows), "ram_mb": med("ram_mb"), "boot_s": med("boot_s"),
                    "disk_mb": med("disk_mb"), "packages": med("packages"), "desktop": rows[-1]["desktop"]})
    if len(rows) < 3:
        print(f"Aviso: {name} só tem {len(rows)} medição(ões). Recomendo pelo menos 3.")

out = Path(__file__).with_name("desempenho-dados.js")
out.write_text("// Gerado por medicoes-para-video.py a partir de medições reais. Não editar à mão.\n"
               "window.DADOS = " + json.dumps({"conditions": conditions, "distros": distros}, ensure_ascii=False, indent=2) + ";\n",
               encoding="utf-8")
print("Escrito:", out)
