"""
PaleoForest — preparación de datos.

  1. data/arackar/       -> ÚNICO conjunto cargado por la app (dataset.js + fuentes)
  2. examples/<Especie>/ -> conjuntos crudos, una carpeta por especie, para cargar a mano

Los nombres del proyecto R original no son confiables ("two", "otro2", ".tre" vs
".tree"), así que aquí cada archivo se clasifica y verifica por CONTENIDO:
  - 'xread'        -> matriz de caracteres TNT
  - 'tread' / '('  -> árboles más parsimoniosos
  - 'TIPS;INI_EON' -> anotaciones de edades
"""
import re, json, os, shutil

SRC = 'codigo/tesis-disenio_final/'
DATA = SRC + 'data/'
OUT_APP = 'project/data/'
OUT_EX = 'project/examples/'


# ---------------------------------------------------------------- parsers
def tnt_tokens(s):
    out = []
    i = 0
    while i < len(s):
        if s[i] == '[':
            j = s.index(']', i)
            out.append(s[i + 1:j])
            i = j + 1
        else:
            out.append(s[i])
            i += 1
    return out


def parse_tnt_matrix(path):
    """Devuelve {taxon: [tokens]} desde la matriz de caracteres TNT."""
    lines = open(path, encoding='latin-1').read().replace('\r', '').split('\n')
    dims_idx = None
    ntax = None
    for i, l in enumerate(lines):
        if l.strip().lower().startswith('xread'):
            for j in range(i + 1, i + 6):
                m = re.match(r"^\s*'*\s*(\d+)\s+(\d+)\s*$", lines[j])
                if m:
                    dims_idx = j
                    ntax = int(m.group(2))
                    break
            break
    if dims_idx is None:
        return {}
    out = {}
    k = dims_idx + 1
    while k < len(lines) and len(out) < ntax:
        l = lines[k]
        k += 1
        s = l.strip()
        if not s or s.startswith('&'):
            continue
        if s == ';' or s.lower().startswith('proc'):
            break
        m = re.match(r'^(\S+)\s+(.+)$', l)
        if m:
            out[m.group(1).strip("'")] = tnt_tokens(m.group(2).strip())
    return out


def parse_tnt_taxa(path):
    lines = open(path, encoding='latin-1').read().split('\n')
    dims_idx = None
    ntax = None
    for i, l in enumerate(lines):
        if l.strip().lower().startswith('xread'):
            for j in range(i + 1, i + 6):
                m = re.match(r"^\s*'*\s*(\d+)\s+(\d+)\s*$", lines[j].replace('\r', ''))
                if m:
                    dims_idx = j
                    ntax = int(m.group(2))
                    break
            break
    if dims_idx is None:
        raise ValueError('sin xread: ' + path)
    taxa = []
    k = dims_idx + 1
    while k < len(lines) and len(taxa) < ntax:
        l = lines[k].rstrip('\r')
        k += 1
        s = l.strip()
        if not s or s.startswith('&'):
            continue
        if s == ';' or s.lower().startswith('proc'):
            break
        m = re.match(r'^(\S+)\s+(.+)$', l)
        if m:
            taxa.append(m.group(1).strip("'"))   # la matriz con ccode los trae entrecomillados
    if len(taxa) != ntax:
        raise ValueError('%s: %d taxones vs %d declarados' % (path, len(taxa), ntax))
    return taxa


def tnt_to_newick(s, names):
    s = s.strip().rstrip('*;').strip()
    pos = 0

    def parse():
        nonlocal pos
        assert s[pos] == '('
        pos += 1
        children = []
        while True:
            while pos < len(s) and s[pos] == ' ':
                pos += 1
            if s[pos] == '(':
                children.append(parse())
            elif s[pos] == ')':
                pos += 1
                break
            else:
                m = re.match(r'\d+', s[pos:])
                num = int(m.group(0))
                pos += len(m.group(0))
                children.append(names[num].replace(' ', '_'))
        return '(' + ','.join(children) + ')'

    while s[pos] == ' ':
        pos += 1
    return parse() + ';'


def parse_trees(path, taxa):
    lines = open(path, encoding='latin-1').read().split('\n')
    return [tnt_to_newick(l, taxa) for l in lines if l.strip().startswith('(')]


def parse_ages(path):
    ann = open(path, encoding='utf-8-sig').read().split('\n')
    header = [h.strip() for h in ann[0].rstrip('\r').split(';')]
    ci = lambda n: header.index(n) if n in header else None
    c = dict(tip=ci('TIPS'), fad=ci('FIRST'), lad=ci('LAST'),
             eon=ci('INI_EON'), era=ci('INI_ERA'), per=ci('INI_PERIOD'),
             epo=ci('INI_EPOCH'), stg=ci('INI_AGE'), diet=ci('DIET'))
    g = lambda cells, i: cells[i].strip() if (i is not None and i < len(cells)) else ''
    ages = {}
    for row in ann[1:]:
        row = row.rstrip('\r')
        if not row.strip():
            continue
        cells = row.split(';')
        try:
            fad = float(g(cells, c['fad']))
            lad = float(g(cells, c['lad']))
        except ValueError:
            continue
        ages[g(cells, c['tip'])] = {
            'fad': fad, 'lad': lad,
            'eon': g(cells, c['eon']), 'era': g(cells, c['era']),
            'period': g(cells, c['per']), 'epoch': g(cells, c['epo']),
            'stage': g(cells, c['stg']), 'diet': g(cells, c['diet'])
        }
    return ages


# ---------------------------------------------------------------- catálogo
# Identificado por los taxones de cada matriz, no por el nombre del archivo.
CASES = [
    dict(folder='Arackar_licanantay',
         # OJO: la matriz buena es 'secuencias_ajustarda', no 'arackar.tnt'.
         # Solo esta reproduce el puntaje publicado (1322) en los 96 arboles.
         tnt=DATA + 'Arackar/secuencias_ajustarda_arackar.tnt',
         tre=DATA + 'Arackar/arboles_TNT_arackar_1322.tre',
         csv=DATA + 'Arackar/anotaciones_arackar_age.csv',
         # Caracteres aditivos segun Rubilar-Rogers et al. (2021), usados como
         # indices 0-based: es la unica lectura que da 1322 en los 96 arboles.
         ordered=[14, 61, 100, 102, 109, 115, 127, 132, 135, 136, 166, 179, 195,
                  256, 259, 276, 277, 278, 279, 299, 303, 346, 352, 354],
         note='Titanosaurio del Cretacico Superior de Atacama, Chile (Rubilar-Rogers et al. 2021).'),
    dict(folder='Burkesuchus_mallingrandensis',
         tnt=DATA + 'secuencias_burkesuchus.tnt',
         tre=DATA + 'arboles_burkesuchus_100_1008.tree',
         csv=DATA + 'anotaciones_burkesuchus_age.csv',
         note='Crocodiliforme del Jurasico Superior de Aysen, Chile.'),
    dict(folder='Chilesaurus_diegosuarezi',
         tnt=DATA + 'chilesaurus/chilesaurus.tnt',
         tre=DATA + 'chilesaurus/chilesaurus.tre',
         csv=None,
         note='Teropodo enigmatico del Jurasico Superior de Aysen, Chile.'),
    dict(folder='Orretherium_tzen',
         tnt=DATA + 'Orretherium/Orretherium.tnt',
         tre=DATA + 'Orretherium/orretherium.tre',
         csv=None,
         note='Mamaliaforme gondwanaterio del Cretacico Superior de Chile.'),
    # two/ y otro2/ son el MISMO archivo (md5 identico). Una sola matriz de 96
    # taxones que contiene a Punatitan y a Bravasaurus: se describieron juntos.
    # Una carpeta, no dos.
    dict(folder='Punatitan_coughlini_Bravasaurus_arrierosorum',
         tnt=DATA + 'two/two.tnt',
         tre=DATA + 'two/two.tre',
         csv=None,
         note='Titanosaurios del Cretacico Superior de La Rioja, Argentina. Ambos taxones '
              'comparten matriz y arboles: es un solo conjunto, no dos.'),
]

APP_CASE = 'Arackar_licanantay'

APP_META = dict(
    key='arackar', name='Arackar licanantay', group='Sauropoda (Titanosauria)',
    desc={
        'es': 'Titanosaurio del Cretácico Superior de la Región de Atacama, Chile. 97 árboles más parsimoniosos, 88 taxones y edades fósiles completas.',
        'en': 'Late Cretaceous titanosaur from the Atacama Region, Chile. 97 most-parsimonious trees, 88 taxa and complete fossil ages.',
        'pt': 'Titanossauro do Cretáceo Superior da Região de Atacama, Chile. 97 árvores mais parcimoniosas, 88 táxons e idades fósseis completas.'
    })

# ---------------------------------------------------------------- build
shutil.rmtree(OUT_EX, ignore_errors=True)
shutil.rmtree(OUT_APP, ignore_errors=True)
os.makedirs(OUT_EX, exist_ok=True)
os.makedirs(OUT_APP, exist_ok=True)

index = []
for c in CASES:
    taxa = parse_tnt_taxa(c['tnt'])
    trees = parse_trees(c['tre'], taxa)
    ages = parse_ages(c['csv']) if c['csv'] else {}
    matched = sum(1 for t in taxa if t in ages)

    d = OUT_EX + c['folder'] + '/'
    os.makedirs(d, exist_ok=True)
    shutil.copyfile(c['tnt'], d + 'matrix.tnt')
    shutil.copyfile(c['tre'], d + 'trees.tre')
    if c['csv']:
        shutil.copyfile(c['csv'], d + 'ages.csv')
    open(d + 'trees.nwk', 'w').write('\n'.join(trees) + '\n')
    json.dump({'species': c['folder'].replace('_', ' '), 'nTrees': len(trees),
               'nTaxa': len(taxa), 'nAges': matched, 'note': c['note'],
               'files': sorted(os.listdir(d))},
              open(d + 'info.json', 'w'), ensure_ascii=False, indent=2)

    index.append((c['folder'], len(trees), len(taxa), matched, bool(c['csv']), c['note']))
    print('%-46s arboles=%3d taxones=%3d edades=%3d' % (c['folder'], len(trees), len(taxa), matched))

    if c['folder'] == APP_CASE:
        os.makedirs(OUT_APP + 'arackar', exist_ok=True)
        payload = dict(APP_META)
        # Referencia de parsimonia: TNT nombra el .tre con el largo de los
        # arboles ("arboles_TNT_arackar_1322.tre"). Es un dato del conjunto,
        # no algo que el usuario deba teclear.
        mref = re.search(r'_(\d{3,5})\.tre[a-z]*$', os.path.basename(c['tre']), re.I)
        payload.update(taxa=taxa, newicks=trees, ages=ages,
                       matrix=parse_tnt_matrix(c['tnt']),
                       ordered=c.get('ordered', []),
                       parsRef=(int(mref.group(1)) if mref else None),
                       parsRefSrc=(os.path.basename(c['tre']) if mref else None),
                       # bloque ccode crudo, para que la app pueda releerlo
                       rawCcode=(re.search(r'ccode[^;]*;', open(c['tnt'], encoding='latin-1').read(), re.I).group(0)
                                 if re.search(r'ccode[^;]*;', open(c['tnt'], encoding='latin-1').read(), re.I) else ''),
                       nTrees=len(trees), nTaxa=len(taxa))
        shutil.copyfile(c['tnt'], OUT_APP + 'arackar/matrix.tnt')
        shutil.copyfile(c['tre'], OUT_APP + 'arackar/trees.tre')
        shutil.copyfile(c['csv'], OUT_APP + 'arackar/ages.csv')
        open(OUT_APP + 'arackar/trees.nwk', 'w').write('\n'.join(trees) + '\n')
        open(OUT_APP + 'arackar/dataset.js', 'w', encoding='utf-8').write(
            '/* Conjunto de ejemplo de PaleoForest: Arackar licanantay.\n'
            '   Generado por tools/prep.py desde matrix.tnt + trees.tre + ages.csv */\n'
            'window.PF_DATA=%s;\n' % json.dumps(payload, ensure_ascii=False))
        json.dump({'species': 'Arackar licanantay', 'nTrees': len(trees), 'nTaxa': len(taxa),
                   'nAges': matched, 'note': c['note']},
                  open(OUT_APP + 'arackar/meta.json', 'w'), ensure_ascii=False, indent=2)

rows = '\n'.join('| `%s/` | %d | %d | %s |' % (f, tr, tx, (str(ag) if csv else '—'))
                 for f, tr, tx, ag, csv, _ in index)
notes = '\n'.join('- **%s** — %s' % (f.replace('_', ' '), n) for f, _, _, _, _, n in index)
open(OUT_EX + 'README.md', 'w', encoding='utf-8').write("""# Conjuntos de ejemplo

Una carpeta por especie, con los datos originales del proyecto R de la memoria.
La aplicación **solo carga Arackar**; estos se usan cargándolos a mano en el paso «Datos»
(`matrix.tnt` + `trees.tre`, y `ages.csv` si la carpeta lo trae).

| Carpeta | Árboles | Taxones | Edades |
|---|---|---|---|
%s

Archivos de cada carpeta:

- `matrix.tnt` — matriz de caracteres TNT (define los nombres de los taxones)
- `trees.tre` — árboles más parsimoniosos en formato TNT
- `trees.nwk` — los mismos árboles en Newick con nombres, por si los quieres en otra herramienta
- `ages.csv` — anotaciones de edades fósiles (solo donde existen)
- `info.json` — conteos y procedencia

## Notas

%s

## Sobre los nombres

Los nombres del proyecto original no eran confiables: `two/` y `otro2/` eran **el mismo
archivo** (md5 idéntico), y los árboles venían con extensiones mezcladas (`.tre` y `.tree`).
Cada conjunto se identificó por sus taxones, no por el nombre del archivo. Se descartaron
`testing/` y `uploads/` por ser recortes y duplicados (`uploads/secuencias.tnt` es byte a
byte igual a `Arackar/arackar.tnt`).

## Qué falta

Solo Arackar y Burkesuchus traen anotaciones de edades. Para los demás, usa el paso
«Edades» de la app: consulta la Paleobiology Database o ingresa los rangos a mano.
""" % (rows, notes))

print('\nexamples/ ->', OUT_EX)
print('app data  ->', OUT_APP + 'arackar/')
