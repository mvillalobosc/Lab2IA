# RheumaCL

[Español](#español) · [English](#english)

## Español

RheumaCL es un dashboard con los resultados de la 1.ª Encuesta de la Red de Pacientes Reumáticos de Chile, por enfermedad y por región: perfil de los pacientes, enfermedades combinadas, tratamientos y brechas de acceso. Está en castellano, inglés y portugués.

Es la versión estática del dashboard Shiny de la encuesta. Está hecho con HTML, CSS y JavaScript, sin librerías: las cifras vienen calculadas en dos archivos de datos y la página solo las muestra. No necesita servidor ni conexión a internet.

El análisis con modelos de aprendizaje automático de la misma encuesta está en [`../RheumaCL_code/`](../RheumaCL_code/).

### Cómo abrirlo

Con doble clic en `index.html`. También se puede publicar copiando la carpeta en cualquier servidor de archivos estáticos.

### Contenido

```
RheumaCL/
├── README.md
├── LICENSE              licencia MIT del código
├── index.html           la página
├── assets/usach.png     logo de la Universidad de Santiago de Chile
├── css/estilos.css      ver css/README.md
├── data/                las dos bases de datos, ver data/README.md
│   ├── bd_encuesta.js
│   └── bd_regiones.js
├── js/                  ver js/README.md
│   ├── textos.js        los textos en los tres idiomas
│   ├── graficos.js      barras, red, mapa y tablas
│   └── app.js           estado, secciones y filtro
└── tools/               ver tools/README.md
    ├── preparar_datos.R genera las dos bases de datos
    └── regiones.json    límites regionales en GeoJSON
```

### Secciones

| Sección | Qué muestra | Filtro |
|---|---|---|
| Resumen | Doce indicadores de quienes declaran la enfermedad: prevalencia en la muestra, discapacidad, dolor, sexo y edad más frecuentes, fármacos, adherencia, gasto y continuidad. | Enfermedad |
| Enfermedades combinadas | Una red en que cada círculo es una enfermedad y cada línea une dos que declara una misma persona, con las combinaciones más frecuentes de la enfermedad elegida. | Enfermedad |
| Perfil del paciente | Sexo, edad, actividad física, dieta, tabaco, alcohol, manejo del dolor, salud percibida, años con diagnóstico, especialista tratante y relación con el médico. | Enfermedad |
| Territorio | Un mapa con los encuestados de cada región y el perfil de la región elegida: enfermedades declaradas, sexo, edad e indicadores de la comuna de residencia. | Región |
| Tratamientos | Uso de cada tipo de fármaco, cuántos tipos usa cada persona, combinaciones más frecuentes, terapias complementarias y cobertura institucional de la enfermedad (GES, guía clínica y Ley Ricarte Soto). | Enfermedad |
| Brechas de acceso | Adherencia y razones para no seguir el tratamiento, situación frente al GES, gasto mensual, financiamiento alternativo, créditos y judicialización. | Enfermedad |
| Sobre los datos | Qué es la encuesta, cómo leer las cifras, las 12 enfermedades y los créditos. | Ninguno |

### Decisiones de uso

- Hay un solo filtro por pantalla, enfermedad o región, siempre en el mismo lugar. Al abrir, el dashboard muestra la enfermedad y la región con más encuestados.
- La sección, la enfermedad, la región y el idioma quedan en la dirección de la página (`#seccion=perfil&enf=V15&reg=13&lang=es`), así que una vista se puede compartir con un enlace y el botón Atrás del navegador funciona.
- Cada gráfico dice sobre cuántas personas se calcula, tiene un botón para ver sus cifras en una tabla y avisa cuando el grupo tiene menos de 30 personas.
- Los porcentajes se calculan sobre quienes respondieron cada pregunta. Las preguntas de respuesta múltiple lo dicen en una nota, porque sus porcentajes no suman 100.
- Los colores son los corporativos de la USACH. Ningún dato depende solo del color: las barras llevan su cifra y las categorías llevan su nombre.
- El mapa se maneja con el puntero; la lista de regiones del filtro hace lo mismo con el teclado y con lectores de pantalla.
- La página se adapta a pantallas de teléfono y de tableta, y el idioma elegido se recuerda en el navegador.

### Datos

`data/bd_encuesta.js` trae solo conteos y porcentajes, por enfermedad y por región. Las respuestas individuales de la encuesta no están en el repositorio. La versión incluida se generó el 16 de noviembre de 2026 con `tools/preparar_datos.R` a partir de `data_encuesta_filtrado.xlsx`, que tiene las respuestas de 1.151 personas. Para actualizarla, revisa [`tools/README.md`](tools/README.md).

Las cifras son las del dashboard Shiny, con tres diferencias:

- El número de encuestados se lee de la base (1.151). Los textos del Shiny decían 1.159.
- "Decisión compartida sobre el tratamiento" (V114) aparecía siempre en 0 % en el Shiny, porque el código comparaba con "Si" y la base trae "SI". Aquí se cuenta bien.
- En la tabla de cobertura institucional, la artrosis figura como cobertura parcial en GES y guía clínica, porque el problema GES n.º 41 cubre solo la artrosis de cadera o rodilla, leve o moderada, desde los 55 años.

### Idiomas

Todos los textos están en `js/textos.js`, con las mismas 341 claves en castellano, inglés y portugués. Para cambiar un texto hay que cambiarlo en los tres idiomas. Los detalles, y cómo agregar un idioma, están en [`js/README.md`](js/README.md).

### Licencia y créditos

El código usa la licencia MIT; ver [`LICENSE`](LICENSE). Las cifras de la encuesta, los límites regionales y el logo de la universidad conservan sus propios términos.

Javiera Vásquez-Salgado y Manuel Villalobos-Cid, Departamento de Ingeniería Informática, Universidad de Santiago de Chile. Datos de la 1.ª Encuesta de la Red de Pacientes Reumáticos de Chile.

## English

RheumaCL is a dashboard with the results of the 1st Survey of the Chilean Network of Rheumatic Patients, by disease and by region: patient profile, combined diseases, treatments and access gaps. It is available in Spanish, English and Portuguese.

It is the static version of the Shiny dashboard of the survey. It is built with HTML, CSS and JavaScript, without libraries: the figures come already computed in two data files and the page only displays them. It needs no server and no internet connection.

The machine learning analysis of the same survey is in [`../RheumaCL_code/`](../RheumaCL_code/).

### How to open it

Double-click `index.html`. It can also be published by copying the folder to any static file server.

### Contents

```
RheumaCL/
├── README.md
├── LICENSE              MIT licence of the code
├── index.html           the page
├── assets/usach.png     logo of the Universidad de Santiago de Chile
├── css/estilos.css      see css/README.md
├── data/                the two databases, see data/README.md
│   ├── bd_encuesta.js
│   └── bd_regiones.js
├── js/                  see js/README.md
│   ├── textos.js        the texts in the three languages
│   ├── graficos.js      bars, network, map and tables
│   └── app.js           state, sections and filter
└── tools/               see tools/README.md
    ├── preparar_datos.R builds the two databases
    └── regiones.json    regional boundaries as GeoJSON
```

### Sections

| Section | What it shows | Filter |
|---|---|---|
| Summary | Twelve indicators of the people who report the disease: prevalence in the sample, disability, pain, most frequent sex and age, drugs, adherence, spending and continuity. | Disease |
| Combined diseases | A network where each circle is a disease and each line joins two reported by the same person, with the most frequent combinations of the selected disease. | Disease |
| Patient profile | Sex, age, physical activity, diet, tobacco, alcohol, pain management, self-rated health, years since diagnosis, treating specialist and relationship with the physician. | Disease |
| Regions | A map with the respondents of each region and the profile of the selected region: reported diseases, sex, age and indicators of the commune of residence. | Region |
| Treatments | Use of each drug type, number of drug types per person, most frequent combinations, complementary therapies and institutional coverage of the disease (GES, clinical guideline and the Ricarte Soto Law). | Disease |
| Access gaps | Adherence and reasons for not following the treatment, GES status, monthly spending, alternative funding, loans and litigation. | Disease |
| About the data | What the survey is, how to read the figures, the 12 diseases and the credits. | None |

### Usability decisions

- Each screen has a single filter, disease or region, always in the same place. On opening, the dashboard shows the disease and the region with the most respondents.
- The section, disease, region and language are kept in the page address (`#seccion=perfil&enf=V15&reg=13&lang=es`), so a view can be shared with a link and the browser Back button works.
- Every chart states how many people it is computed on, has a button to see its figures as a table and warns when the group has fewer than 30 people.
- Percentages are computed over the people who answered each question. Multiple-answer questions say so in a note, because their percentages do not add up to 100.
- The colours are the corporate colours of USACH. No value depends on colour alone: bars carry their figure and categories carry their name.
- The map is operated with the pointer; the list of regions in the filter does the same with the keyboard and with screen readers.
- The page adapts to phone and tablet screens, and the selected language is remembered in the browser.

### Data

`data/bd_encuesta.js` holds only counts and percentages, by disease and by region. The individual answers of the survey are not in the repository. The included version was generated on 16 November 2026 with `tools/preparar_datos.R` from `data_encuesta_filtrado.xlsx`, which has the answers of 1,151 people. To update it, see [`tools/README.md`](tools/README.md).

The figures are those of the Shiny dashboard, with three differences:

- The number of respondents is read from the database (1,151). The Shiny texts said 1,159.
- "Shared decision on the treatment" (V114) always showed 0 % in Shiny, because the code compared with "Si" and the dataset holds "SI". Here it is counted correctly.
- In the institutional coverage table, osteoarthritis appears with partial coverage for GES and clinical guideline, because GES health problem No. 41 covers only mild or moderate hip or knee osteoarthritis from the age of 55.

### Languages

All the texts are in `js/textos.js`, with the same 341 keys in Spanish, English and Portuguese. A text change must be made in the three languages. The details, and how to add a language, are in [`js/README.md`](js/README.md).

### Licence and credits

Code under the MIT licence, see [`LICENSE`](LICENSE). The survey figures, the regional boundaries and the university logo keep their own terms.

Javiera Vásquez-Salgado and Manuel Villalobos-Cid, Department of Informatics Engineering, Universidad de Santiago de Chile. Data from the 1st Survey of the Chilean Network of Rheumatic Patients.
