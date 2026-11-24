#!/usr/bin/env python3
"""Compara dos capturas del login y dice cuántos píxeles cambian.

Se usa para la prueba de fidelidad: el tema, alimentado con los datos del
prototipo, tiene que dar exactamente el mismo dibujo que el prototipo. El
script falla (código 1) si la diferencia supera el umbral permitido, de modo
que puede formar parte de la QA sin revisión manual.

Uso:
  python3 scripts/lib/comparar-capturas.py referencia.png candidata.png
  python3 scripts/lib/comparar-capturas.py a.png b.png --umbral 0 --informe diff.png
"""
from __future__ import annotations

import argparse
import sys
from pathlib import Path


def cargar(ruta: Path):
    try:
        from PIL import Image
    except ImportError:  # pragma: no cover - depende del entorno
        raise SystemExit("Falta Pillow: instala python3-pil para comparar capturas.")
    return Image.open(ruta).convert("RGB")


def comparar(referencia: Path, candidata: Path, umbral: int = 0,
             tolerancia: int = 0):
    """Devuelve (píxeles distintos, total, caja de la diferencia).

    `tolerancia` es la diferencia máxima por canal que se considera igual: con
    0 la comparación es exacta, que es lo que exige la fidelidad del prototipo.
    """
    a = cargar(referencia)
    b = cargar(candidata)
    if a.size != b.size:
        return a.size[0] * a.size[1], a.size[0] * a.size[1], a.size, b.size

    from PIL import ImageChops

    if tolerancia > 0:
        from PIL import ImageFilter
        # Un desenfoque mínimo absorbe el ruido de compresión sin tapar cambios
        # de layout: cualquier texto movido sigue superando la tolerancia.
        a = a.filter(ImageFilter.GaussianBlur(0.5))
        b = b.filter(ImageFilter.GaussianBlur(0.5))
        diferencia = ImageChops.difference(a, b)
        canales = diferencia.split()
        maximo = canales[0]
        for canal in canales[1:]:
            maximo = ImageChops.lighter(maximo, canal)
        mascara = maximo.point(lambda v: 255 if v > tolerancia else 0)
    else:
        diferencia = ImageChops.difference(a, b)
        mascara = diferencia.convert("L").point(lambda v: 255 if v else 0)

    distintos = sum(1 for valor in mascara.getdata() if valor)
    return distintos, a.size[0] * a.size[1], a.size, a.size


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description=__doc__,
                                     formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("referencia", type=Path)
    parser.add_argument("candidata", type=Path)
    parser.add_argument("--umbral", type=int, default=0,
                        help="píxeles distintos permitidos (por defecto 0)")
    parser.add_argument("--tolerancia", type=int, default=0,
                        help="diferencia máxima por canal que cuenta como igual")
    parser.add_argument("--informe", type=Path,
                        help="guarda un PNG con la diferencia marcada en rojo")
    args = parser.parse_args(argv)

    distintos, total, tam_a, tam_b = comparar(args.referencia, args.candidata,
                                             args.umbral, args.tolerancia)
    if tam_a != tam_b:
        print(f"Tamaños distintos: {tam_a} frente a {tam_b}")
        return 1

    if args.informe:
        from PIL import Image, ImageChops
        a = cargar(args.referencia)
        b = cargar(args.candidata)
        diferencia = ImageChops.difference(a, b).convert("L")
        marcado = a.copy()
        rojo = Image.new("RGB", a.size, (255, 0, 64))
        mascara = diferencia.point(lambda v: 255 if v else 0)
        marcado.paste(rojo, (0, 0), mascara)
        args.informe.parent.mkdir(parents=True, exist_ok=True)
        marcado.save(args.informe)

    porcentaje = 100.0 * distintos / total if total else 0.0
    estado = "idénticas" if distintos == 0 else f"{distintos} píxeles distintos"
    print(f"{args.referencia.name} frente a {args.candidata.name}: {estado} "
          f"({porcentaje:.3f} % de {total})")
    if distintos > args.umbral:
        print(f"Supera el umbral de {args.umbral} píxeles.", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
