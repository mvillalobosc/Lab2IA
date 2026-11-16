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
│   ├── graficos.js      íconos, ayudas, barras, red, mapa y tablas
│   └── app.js           estado, vistas, pestañas, guía y bienvenida
└── tools/               ver tools/README.md
    ├── preparar_datos.R genera las dos bases de datos
    └── regiones.json    límites regionales en GeoJSON
```

### Vistas

La barra superior tiene dos vistas. A la izquierda se elige el grupo y a la derecha se ve su ficha.

**Por enfermedad.** El panel de la izquierda lista las 12 enfermedades con el número de personas que declara cada una. La ficha muestra la enfermedad elegida en cinco pestañas:

| Pestaña | Qué muestra |
|---|---|
| Resumen | Doce indicadores en cuatro bloques: epidemiología, perfil del paciente, tratamiento y brechas de acceso. |
| Enfermedades combinadas | Una red en que cada círculo es una enfermedad y cada línea une dos que declara una misma persona, con las combinaciones más frecuentes de la enfermedad elegida. Un clic en un círculo cambia de enfermedad. |
| Perfil del paciente | Sexo, edad, actividad física, dieta, tabaco, alcohol, salud percibida, manejo del dolor, años con diagnóstico, especialista tratante y relación con el médico. |
| Tratamientos | Uso de cada tipo de fármaco, cuántos tipos usa cada persona, combinaciones más frecuentes, terapias complementarias y cobertura institucional de la enfermedad (GES, guía clínica y Ley Ricarte Soto). |
| Brechas de acceso | Adherencia y razones para no seguir el tratamiento, GES y seguros, gasto mensual, financiamiento alternativo, créditos y judicialización. |

**Por región.** El panel de la izquierda trae el mapa de Chile y la lista de regiones de norte a sur, coloreados según cuántas personas respondieron. La ficha muestra a quienes viven en la región elegida: atención fuera de la región, discapacidad, enfermedades declaradas, sexo, edad e indicadores de la comuna de residencia.

### Ayudas y decisiones de uso

- **Bienvenida.** La primera visita abre una presentación de tres pasos (elegir una enfermedad, recorrer las pestañas y abrir las ayudas). Tiene una casilla para no volver a mostrarla.
- **Botón "?".** Cada cifra y cada gráfico tiene un "?" que explica qué muestra y sobre quiénes se calcula. Se abre con el puntero, con el teclado o al tocarlo.
- **Guía de uso.** El botón Ayuda abre un panel con cinco pestañas: cómo usar, cómo leer las cifras, qué trae cada sección, un glosario de 19 términos (GES, Ley Ricarte Soto, biológicos, adherencia y otros) y el origen de los datos.
- **Menos ruido.** En Perfil, Tratamientos y Brechas de acceso los gráficos van en grupos que se abren y se cierran. Al entrar solo el primero está abierto y los demás dicen qué gráficos traen; "Abrir todo" los muestra todos.
- **Cada acceso una sola vez.** El grupo se elige en el panel de la izquierda, la vista en la barra superior y el tema en las pestañas. Ningún botón se repite en otro lugar.
- **Tabla y descarga.** Cada gráfico tiene un botón para ver sus cifras en una tabla y otro para descargarlas en CSV.
- **Enlace.** La vista, la enfermedad, la región, la pestaña y el idioma quedan en la dirección de la página (`#modo=enfermedad&seccion=perfil&enf=V15&reg=13&lang=es`). "Copiar enlace" la copia, y el botón Atrás del navegador funciona.
- **Grupos pequeños.** Cuando un grupo tiene menos de 30 personas, la ficha lo avisa.
- **Lectura.** Cada gráfico dice sobre cuántas personas se calcula; las preguntas de respuesta múltiple lo advierten, porque sus porcentajes no suman 100. Ningún dato depende solo del color: las barras llevan su cifra y las categorías su nombre.
- **Teclado y pantallas.** Las pestañas se recorren con las flechas, el foco vuelve a la opción elegida tras cada cambio y la guía y la bienvenida retienen el foco mientras están abiertas. En teléfonos y tabletas el panel de la izquierda se convierte en una lista desplegable. El idioma elegido se recuerda en el navegador.
- **Colores.** Son los corporativos de la USACH (azul verdoso, naranja y grafito) en tonos pastel. Como un pastel se distingue poco sobre blanco, cada barra lleva su cifra y los fármacos van agrupados por categoría con su subtítulo.

### Datos

`data/bd_encuesta.js` trae solo conteos y porcentajes, por enfermedad y por región. Las respuestas individuales de la encuesta no están en el repositorio. La versión incluida se generó el 16 de noviembre de 2026 con `tools/preparar_datos.R` a partir de `data_encuesta_filtrado.xlsx`, que tiene las respuestas de 1.151 personas. Para actualizarla, revisa [`tools/README.md`](tools/README.md).

Las cifras son las del dashboard Shiny, con tres diferencias:

- El número de encuestados se lee de la base (1.151). Los textos del Shiny decían 1.159.
- "Decisión compartida sobre el tratamiento" (V114) aparecía siempre en 0 % en el Shiny, porque el código comparaba con "Si" y la base trae "SI". Aquí se cuenta bien.
- En la tabla de cobertura institucional, la artrosis figura como cobertura parcial en GES y guía clínica, porque el problema GES n.º 41 cubre solo la artrosis de cadera o rodilla, leve o moderada, desde los 55 años.

### Idiomas

Todos los textos están en `js/textos.js`, con los mismos 470 textos en castellano, inglés y portugués. Para cambiar un texto hay que cambiarlo en los tres idiomas. Los detalles, y cómo agregar un idioma, están en [`js/README.md`](js/README.md).

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
│   ├── graficos.js      icons, help, bars, network, map and tables
│   └── app.js           state, views, tabs, guide and welcome
└── tools/               see tools/README.md
    ├── preparar_datos.R builds the two databases
    └── regiones.json    regional boundaries as GeoJSON
```

### Views

The top bar offers two views. The group is chosen on the left and its profile is shown on the right.

**By disease.** The left panel lists the 12 diseases with the number of people who report each one. The profile shows the chosen disease in five tabs:

| Tab | What it shows |
|---|---|
| Summary | Twelve indicators in four blocks: epidemiology, patient profile, treatment and access gaps. |
| Combined diseases | A network where each circle is a disease and each line joins two reported by the same person, with the most frequent combinations of the chosen disease. A click on a circle changes the disease. |
| Patient profile | Sex, age, physical activity, diet, tobacco, alcohol, self-rated health, pain management, years since diagnosis, treating specialist and relationship with the physician. |
| Treatments | Use of each drug type, number of drug types per person, most frequent combinations, complementary therapies and institutional coverage of the disease (GES, clinical guideline and the Ricarte Soto Law). |
| Access gaps | Adherence and reasons for not following the treatment, GES and insurance, monthly spending, alternative funding, loans and court action. |

**By region.** The left panel holds the map of Chile and the list of regions from north to south, coloured by the number of people who answered. The profile shows the people who live in the chosen region: care outside the region, disability, reported diseases, sex, age and indicators of the commune of residence.

### Help and usability decisions

- **Welcome.** The first visit opens a three-step introduction (choose a disease, go through the tabs and open the help). A checkbox stops it from showing again.
- **"?" button.** Every figure and chart has a "?" that explains what it shows and over whom it is computed. It opens with the pointer, with the keyboard or with a tap.
- **User guide.** The Help button opens a panel with five tabs: how to use, how to read the figures, what each section holds, a glossary of 19 terms (GES, Ricarte Soto Law, biologics, adherence and others) and the origin of the data.
- **Less clutter.** In Patient profile, Treatments and Access gaps the charts sit in groups that open and close. On entry only the first group is open and the others list the charts they hold; "Open all" shows them all.
- **Each access only once.** The group is chosen in the left panel, the view in the top bar and the topic in the tabs. No button is repeated elsewhere.
- **Table and download.** Every chart has a button to see its figures as a table and another to download them as CSV.
- **Link.** The view, disease, region, tab and language are kept in the page address (`#modo=enfermedad&seccion=perfil&enf=V15&reg=13&lang=es`). "Copy link" copies it, and the browser Back button works.
- **Small groups.** When a group has fewer than 30 people, the profile says so.
- **Reading.** Every chart states how many people it is computed on; multiple-answer questions warn that their percentages do not add up to 100. No value depends on colour alone: bars carry their figure and categories carry their name.
- **Keyboard and screens.** The tabs are browsed with the arrow keys, focus returns to the chosen option after each change, and the guide and the welcome keep the focus while open. On phones and tablets the left panel becomes a drop-down list. The chosen language is remembered in the browser.
- **Colours.** They are the corporate colours of USACH (teal, orange and graphite) in pastel shades. Since a pastel shade stands out little on white, every bar carries its figure and the drugs are grouped by category under a subtitle.

### Data

`data/bd_encuesta.js` holds only counts and percentages, by disease and by region. The individual answers of the survey are not in the repository. The included version was generated on 16 November 2026 with `tools/preparar_datos.R` from `data_encuesta_filtrado.xlsx`, which has the answers of 1,151 people. To update it, see [`tools/README.md`](tools/README.md).

The figures are those of the Shiny dashboard, with three differences:

- The number of respondents is read from the database (1,151). The Shiny texts said 1,159.
- "Shared decision on the treatment" (V114) always showed 0 % in Shiny, because the code compared with "Si" and the dataset holds "SI". Here it is counted correctly.
- In the institutional coverage table, osteoarthritis appears with partial coverage for GES and clinical guideline, because GES health problem No. 41 covers only mild or moderate hip or knee osteoarthritis from the age of 55.

### Languages

All the texts are in `js/textos.js`, with the same 470 texts in Spanish, English and Portuguese. A text change must be made in the three languages. The details, and how to add a language, are in [`js/README.md`](js/README.md).

### Licence and credits

Code under the MIT licence, see [`LICENSE`](LICENSE). The survey figures, the regional boundaries and the university logo keep their own terms.

Javiera Vásquez-Salgado and Manuel Villalobos-Cid, Department of Informatics Engineering, Universidad de Santiago de Chile. Data from the 1st Survey of the Chilean Network of Rheumatic Patients.
