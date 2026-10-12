/* ============================================================================
   ResearchAnalyser · motor del asistente local (compartido por los dos módulos)
   ----------------------------------------------------------------------------
   Sin API ni servidor. Entiende una pregunta en español, inglés o portugués
   como una INTENCIÓN (contar, listar, ranking, comparar, coautores, temas,
   evolución, fuentes, países, métricas, definir...) más CONDICIONES que se
   combinan (persona, años, cuartil, indexación, tipo de documento, tema,
   programa, país, enlace, cantidad). Aplica las condiciones sobre las filas
   del filtro activo y responde diciendo qué entendió, para que el resultado
   sea verificable.

   Cada módulo lo configura con sus campos (ver app_chat.js de publicaciones
   y de tesis). El motor no sabe nada de la interfaz: devuelve HTML.
   ============================================================================ */
(function(){
'use strict';

/* ---------- utilidades ---------- */
const norm = s => String(s ?? '').normalize('NFD').replace(/[̀-ͯ]/g, '').toLowerCase().replace(/[’'`´]/g, ' ').trim();
const esc = s => String(s ?? '').replace(/[&<>"']/g, m => ({ '&':'&amp;', '<':'&lt;', '>':'&gt;', '"':'&quot;', "'":'&#39;' }[m]));
const uniq = a => [...new Set(a)];
const int = v => { const n = parseInt(String(v ?? '').replace(/[^\d-]/g, ''), 10); return Number.isFinite(n) ? n : 0; };
const fmtN = (n, lang) => new Intl.NumberFormat(lang === 'en' ? 'en-GB' : lang === 'pt' ? 'pt-BR' : 'es-CL').format(n);
const count = (rows, f) => { const m = new Map(); rows.forEach(r => { const v = f(r); (Array.isArray(v) ? v : [v]).forEach(x => { if (x !== undefined && x !== null && x !== '') m.set(x, (m.get(x) || 0) + 1); }); }); return [...m.entries()].sort((a, b) => b[1] - a[1]); };
const words = s => norm(s).replace(/[^a-z0-9\s-]/g, ' ').split(/\s+/).filter(Boolean);
const reEsc = s => s.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
/* raíz simple: "sistemas" → "sistema", "networks" → "network" (sirve para singular/plural) */
const stem = t => (t.length >= 5 && /s$/.test(t) && !/ss$/.test(t)) ? t.slice(0, -1) : t;
/* patrón de un término o frase: cada palabra por su raíz y con inicio de palabra; las muy cortas, exactas */
const reCache = new Map();
function patron(v) {
  if (reCache.has(v)) return reCache.get(v);
  const ws = words(v);
  const src = '\\b' + ws.map(w => w.length <= 3 ? reEsc(w) + '\\b' : reEsc(stem(w)) + '\\w*').join('[\\s-]+');
  const re = new RegExp(src);
  reCache.set(v, re);
  return re;
}
const has = (text, v) => patron(v).test(text);

/* Palabras que no sirven para reconocer nombres ni temas */
const STOP = new Set(('de del la las los el un una unos unas y e o u a al en con por para sobre acerca que qué cual cuál cuales cuáles como cómo donde dónde quien quién quienes quiénes cuando cuándo cuanto cuánto cuanta cuánta cuantos cuántos cuantas cuántas hay son es esta está estan están tiene tienen tuvo hubo fue ser estar hecho hechos hecha hechas realizado realizados realizada realizadas ' +
  'me mi mis tu tus su sus se lo le les nos este esta estos estas ese esa esos esas eso esto aquel ' +
  'the of in on at to for from with and or by about which what who whom whose where when how many much is are was were be been has have had do does did there their this that these those it its ' +
  'do da dos das no na nos nas em um uma uns umas e ou com por para sobre que qual quais quem quando quanto quanta quantos quantas onde como tem têm há é são foi feito feitos ' +
  'dame muestra muestrame muéstrame mostrar ver lista listar listame busca buscar buscame búscame encuentra quiero necesito dime di cuenta cuentame cuéntame indica puedes podrias podrías por favor porfa favor gracias ' +
  'show me list find search give tell want need please ' +
  'mostra mostre liste busque encontre quero preciso diga ' +
  'publicacion publicaciones paper papers articulo articulos artículo artículos trabajo trabajos registro registros publication publications article articles work works publicacao publicacoes publicação publicações artigo artigos trabalho trabalhos ' +
  'memoria memorias tesis thesis theses tesina tesinas titulacion titulación proyecto proyectos project projects final ' +
  'autor autores author authors academico academicos académico académicos academica academicas académica académicas profesor profesores profesora profesoras docente docentes investigador investigadores acadêmico acadêmicos ' +
  'guia guias guía guías coguia coguias co-guia co-guias coguía coguías co-guía co-guías tutor tutores director directores orientador orientadores advisor advisors supervisor supervisors guiado guiados guiada guiadas dirigido dirigidos dirigida dirigidas orientado orientados orientada orientadas advised advising advise supervised supervising guided directed led ' +
  'todo todos toda todas all every each cada total totales ' +
  'año anio años anios year years ano anos periodo período ultimo ultimos último últimos last recent recientes reciente ' +
  'top mas más most mejor mejores best primer primera primeras primeros first ' +
  'tema temas topic topics tópico tópicos area areas área áreas linea lineas línea líneas ' +
  'resumen summary resumo panorama dato datos data base bd csv campo campos field fields ' +
  'publica publican publico publicar publicado publicada publicados publicadas publish published publishes publishing publicam publicou escribio escribieron wrote written hizo hicieron realizo realizaron dirigio dirigieron guio guiaron ' +
  'frecuente frecuentes frequent frequente frequentes comun comunes common principal principales main ' +
  'interna interno internas internos externa externo externas externos internal external general generales dentro fuera unidad departamento unit department ' +
  'mais menos menor maior mayor menor sao esta estao ha tem ser estar existe existen existem exist exists ' +
  'aplicacion aplicaciones application applications aplicacao aplicacoes uso usos use using utilizando usando mediante through via basado basada basados basadas based ' +
  'orientou orientaram orienta orientam guiou dirigiu dirigiram teve tinha tiveram escreveu publicaram realizou realizaram fez fizeram advises advised supervises').split(/\s+/).map(norm));

/* Sinónimos entre idiomas que comparten los dos módulos (el módulo puede añadir más) */
const SINONIMOS = {
  'inteligencia artificial': ['artificial intelligence', 'inteligencia artificial', 'ai', 'ia'],
  'artificial intelligence': ['inteligencia artificial', 'ai', 'ia'],
  'ia': ['inteligencia artificial', 'artificial intelligence'],
  'ai': ['artificial intelligence', 'inteligencia artificial'],
  'aprendizaje automatico': ['machine learning', 'aprendizado de maquina', 'aprendizaje de maquina'],
  'aprendizado de maquina': ['machine learning', 'aprendizaje automatico'],
  'machine learning': ['aprendizaje automatico', 'aprendizado de maquina', 'aprendizaje de maquina'],
  'aprendizaje profundo': ['deep learning', 'redes neuronales', 'neural network'],
  'deep learning': ['aprendizaje profundo', 'redes neuronales', 'neural network'],
  'redes neuronales': ['neural network', 'deep learning', 'redes neurais'],
  'neural networks': ['redes neuronales', 'redes neurais', 'deep learning'],
  'procesamiento de lenguaje natural': ['natural language processing', 'nlp'],
  'natural language processing': ['procesamiento de lenguaje natural', 'processamento de linguagem natural'],
  'nlp': ['natural language processing', 'procesamiento de lenguaje natural'],
  'mineria de datos': ['data mining', 'mineracao de dados'],
  'data mining': ['mineria de datos', 'mineracao de dados'],
  'ciencia de datos': ['data science', 'ciencia de dados'],
  'data science': ['ciencia de datos', 'ciencia de dados'],
  'big data': ['datos masivos', 'grandes volumenes de datos'],
  'vision computacional': ['computer vision', 'vision por computador', 'visao computacional'],
  'vision por computador': ['computer vision', 'vision computacional'],
  'computer vision': ['vision computacional', 'vision por computador', 'visao computacional'],
  'interaccion humano computador': ['human-computer interaction', 'human computer interaction', 'hci'],
  'human-computer interaction': ['interaccion humano computador', 'hci'],
  'hci': ['human-computer interaction', 'interaccion humano computador'],
  'ingenieria de software': ['software engineering', 'engenharia de software'],
  'software engineering': ['ingenieria de software', 'engenharia de software'],
  'engenharia de software': ['software engineering', 'ingenieria de software'],
  'seguridad': ['security', 'seguranca', 'ciberseguridad', 'cybersecurity'],
  'security': ['seguridad', 'seguranca', 'cybersecurity'],
  'seguranca': ['security', 'seguridad'],
  'ciberseguridad': ['cybersecurity', 'cyber security', 'security', 'seguridad informatica'],
  'cybersecurity': ['ciberseguridad', 'cyber security', 'seguridad informatica'],
  'redes': ['network', 'networking', 'redes de computadores'],
  'networks': ['redes', 'networking'],
  'bases de datos': ['database', 'databases', 'banco de dados'],
  'base de datos': ['database', 'databases', 'banco de dados'],
  'database': ['bases de datos', 'base de datos', 'banco de dados'],
  'banco de dados': ['database', 'bases de datos'],
  'educacion': ['education', 'educacao', 'ensenanza', 'teaching', 'learning'],
  'education': ['educacion', 'educacao', 'teaching'],
  'educacao': ['education', 'educacion'],
  'estudiantes': ['student', 'students', 'estudantes', 'alumnos'],
  'students': ['estudiantes', 'estudantes', 'alumnos'],
  'salud': ['health', 'saude', 'medical', 'clinical', 'medico', 'clinico'],
  'health': ['salud', 'saude', 'medical', 'clinical'],
  'saude': ['health', 'salud'],
  'biomedica': ['biomedical', 'biomedicina'],
  'biomedical': ['biomedica', 'biomedicina'],
  'imagenes medicas': ['medical imaging', 'medical image', 'imagens medicas'],
  'medical imaging': ['imagenes medicas', 'medical image'],
  'bioinformatica': ['bioinformatics'],
  'bioinformatics': ['bioinformatica'],
  'optimizacion': ['optimization', 'optimisation', 'otimizacao'],
  'optimization': ['optimizacion', 'optimisation', 'otimizacao'],
  'algoritmos geneticos': ['genetic algorithm', 'genetic algorithms', 'algoritmo genetico'],
  'genetic algorithms': ['algoritmos geneticos', 'algoritmo genetico'],
  'metaheuristicas': ['metaheuristic', 'metaheuristics', 'meta-heuristic'],
  'metaheuristics': ['metaheuristicas', 'meta-heuristic'],
  'juegos': ['game', 'games', 'videojuego', 'videojuegos', 'jogos', 'gamification', 'gamificacion'],
  'games': ['juegos', 'videojuegos', 'jogos'],
  'videojuegos': ['video game', 'video games', 'videogame', 'videogames', 'videojuego', 'serious game', 'juego serio', 'jogos digitais', 'gamification', 'gamificacion'],
  'realidad virtual': ['virtual reality', 'realidade virtual', 'vr'],
  'virtual reality': ['realidad virtual', 'realidade virtual'],
  'realidad aumentada': ['augmented reality', 'realidade aumentada', 'ar'],
  'augmented reality': ['realidad aumentada', 'realidade aumentada'],
  'movil': ['mobile', 'android', 'smartphone', 'moviles', 'celular'],
  'moviles': ['mobile', 'android', 'smartphone', 'movil', 'celular'],
  'mobile': ['movil', 'moviles', 'android', 'smartphone'],
  'web': ['web', 'sitio web', 'website', 'aplicacion web'],
  'nube': ['cloud', 'cloud computing', 'nuvem'],
  'cloud': ['nube', 'cloud computing', 'nuvem'],
  'internet de las cosas': ['internet of things', 'iot', 'internet das coisas'],
  'internet of things': ['internet de las cosas', 'iot', 'internet das coisas'],
  'iot': ['internet of things', 'internet de las cosas'],
  'blockchain': ['cadena de bloques', 'blockchain', 'smart contract'],
  'robotica': ['robotics', 'robot', 'robots'],
  'robotics': ['robotica', 'robot'],
  'agentes': ['agent', 'agents', 'multiagente', 'multi-agent', 'agentes'],
  'agents': ['agentes', 'multi-agent', 'multiagente'],
  'simulacion': ['simulation', 'simulacao'],
  'simulation': ['simulacion', 'simulacao'],
  'computacion paralela': ['parallel computing', 'parallel', 'paralelismo', 'gpu'],
  'parallel computing': ['computacion paralela', 'paralelismo', 'gpu'],
  'sistemas distribuidos': ['distributed systems', 'distributed', 'distribuido'],
  'distributed systems': ['sistemas distribuidos', 'distribuido'],
  'alto rendimiento': ['high performance', 'hpc', 'high-performance'],
  'high performance computing': ['alto rendimiento', 'hpc', 'computacion de alto rendimiento'],
  'recuperacion de informacion': ['information retrieval', 'recuperacao de informacao'],
  'information retrieval': ['recuperacion de informacion', 'recuperacao de informacao'],
  'procesamiento de imagenes': ['image processing', 'processamento de imagens'],
  'image processing': ['procesamiento de imagenes', 'processamento de imagens'],
  'reconocimiento de patrones': ['pattern recognition', 'reconhecimento de padroes'],
  'pattern recognition': ['reconocimiento de patrones', 'reconhecimento de padroes'],
  'series de tiempo': ['time series', 'series temporales', 'series temporais'],
  'time series': ['series de tiempo', 'series temporales'],
  'analisis de sentimientos': ['sentiment analysis', 'analise de sentimentos', 'opinion mining'],
  'sentiment analysis': ['analisis de sentimientos', 'opinion mining'],
  'redes sociales': ['social network', 'social networks', 'social media', 'redes sociais'],
  'social networks': ['redes sociales', 'social media', 'redes sociais'],
  'usabilidad': ['usability', 'usabilidade', 'user experience', 'ux'],
  'usability': ['usabilidad', 'usabilidade', 'user experience'],
  'experiencia de usuario': ['user experience', 'ux', 'usability'],
  'user experience': ['experiencia de usuario', 'ux', 'usabilidad'],
  'accesibilidad': ['accessibility', 'acessibilidade'],
  'accessibility': ['accesibilidad', 'acessibilidade'],
  'pruebas de software': ['software testing', 'testing', 'teste de software'],
  'software testing': ['pruebas de software', 'testing', 'teste de software'],
  'requisitos': ['requirements', 'requisitos', 'requirement'],
  'requirements': ['requisitos', 'requirement'],
  'arquitectura de software': ['software architecture', 'arquitetura de software', 'microservicios', 'microservices'],
  'software architecture': ['arquitectura de software', 'arquitetura de software'],
  'metodologias agiles': ['agile', 'scrum', 'agil', 'metodologias ageis'],
  'agile': ['agil', 'agiles', 'scrum', 'metodologias agiles'],
  'scrum': ['scrum', 'agile', 'agil'],
  'gestion de proyectos': ['project management', 'gestao de projetos'],
  'project management': ['gestion de proyectos', 'gestao de projetos'],
  'calidad de software': ['software quality', 'qualidade de software'],
  'software quality': ['calidad de software', 'qualidade de software'],
  'sistemas de recomendacion': ['recommender system', 'recommender systems', 'recommendation', 'sistemas de recomendacao'],
  'recommender systems': ['sistemas de recomendacion', 'recommendation', 'sistemas de recomendacao'],
  'bioinformatics': ['bioinformatica', 'genomics', 'genomica'],
  'genomica': ['genomics', 'genome', 'genoma'],
  'genomics': ['genomica', 'genome', 'genoma'],
  'proteinas': ['protein', 'proteins', 'proteinas'],
  'proteins': ['proteinas', 'protein'],
  'cancer': ['cancer', 'tumor', 'oncology', 'oncologia'],
  'covid': ['covid-19', 'covid', 'coronavirus', 'sars-cov-2', 'pandemic', 'pandemia'],
  'pandemia': ['pandemic', 'covid-19', 'covid', 'coronavirus'],
  'electroencefalografia': ['eeg', 'electroencephalography', 'electroencephalogram'],
  'eeg': ['electroencephalography', 'electroencefalografia', 'electroencephalogram'],
  'senales': ['signal', 'signals', 'sinais', 'signal processing'],
  'signals': ['senales', 'sinais', 'signal processing'],
  'ontologias': ['ontology', 'ontologies', 'ontologia', 'semantic web', 'web semantica'],
  'ontologies': ['ontologias', 'ontologia', 'semantic web'],
  'web semantica': ['semantic web', 'ontology', 'ontologies', 'linked data'],
  'semantic web': ['web semantica', 'ontology', 'linked data'],
  'mineria de texto': ['text mining', 'mineracao de texto', 'text analysis'],
  'text mining': ['mineria de texto', 'mineracao de texto'],
  'chatbot': ['chatbot', 'chatbots', 'conversational agent', 'asistente virtual'],
  'computacion cuantica': ['quantum computing', 'quantum', 'computacao quantica'],
  'quantum computing': ['computacion cuantica', 'quantum', 'computacao quantica'],
  'energia': ['energy', 'energia', 'electric', 'electrico', 'power'],
  'energy': ['energia', 'electric', 'power'],
  'mineria': ['mining', 'mineria', 'mineracao'],
  'mining': ['mineria', 'mineracao'],
  'transporte': ['transport', 'transportation', 'traffic', 'trafico', 'transito'],
  'transport': ['transporte', 'transportation', 'traffic'],
  'ciudades inteligentes': ['smart city', 'smart cities', 'cidades inteligentes'],
  'smart cities': ['ciudades inteligentes', 'smart city', 'cidades inteligentes'],
  'gobierno': ['government', 'governo', 'gobierno electronico', 'e-government'],
  'gobierno electronico': ['e-government', 'egovernment', 'electronic government'],
  'e-government': ['gobierno electronico', 'egovernment', 'electronic government'],
  'comercio electronico': ['e-commerce', 'ecommerce', 'electronic commerce', 'comercio eletronico'],
  'e-commerce': ['comercio electronico', 'ecommerce', 'electronic commerce'],
  'logistica': ['logistics', 'logistica', 'supply chain', 'cadena de suministro'],
  'logistics': ['logistica', 'supply chain'],
  'programacion': ['programming', 'programacao', 'coding'],
  'programming': ['programacion', 'programacao', 'coding'],
  'algoritmos': ['algorithm', 'algorithms', 'algoritmo'],
  'algorithms': ['algoritmos', 'algoritmo'],
  'grafos': ['graph', 'graphs', 'grafo'],
  'graphs': ['grafos', 'grafo'],
  'criptografia': ['cryptography', 'crypto', 'cifrado', 'encryption', 'criptografia'],
  'cryptography': ['criptografia', 'encryption', 'cifrado'],
  'privacidad': ['privacy', 'privacidade'],
  'privacy': ['privacidad', 'privacidade'],
  'ciencia abierta': ['open science', 'open data', 'datos abiertos'],
  'datos abiertos': ['open data', 'dados abertos', 'ciencia abierta'],
  'open data': ['datos abiertos', 'dados abertos', 'open science'],
  'sistemas embebidos': ['embedded systems', 'embedded', 'sistemas embarcados'],
  'embedded systems': ['sistemas embebidos', 'embedded', 'sistemas embarcados'],
  'drones': ['drone', 'drones', 'uav', 'unmanned aerial'],
  'vehiculos autonomos': ['autonomous vehicle', 'autonomous vehicles', 'self-driving', 'veiculos autonomos'],
  'autonomous vehicles': ['vehiculos autonomos', 'self-driving', 'veiculos autonomos'],
  'bioingenieria': ['bioengineering', 'biomedical engineering', 'bioengenharia'],
  'bioengineering': ['bioingenieria', 'biomedical engineering', 'bioengenharia'],
  'rehabilitacion': ['rehabilitation', 'reabilitacao'],
  'rehabilitation': ['rehabilitacion', 'reabilitacao'],
  'neurociencia': ['neuroscience', 'neural', 'brain', 'cerebro', 'neurociencia'],
  'neuroscience': ['neurociencia', 'neural', 'brain', 'cerebro'],
  'cerebro': ['brain', 'neural', 'neurociencia', 'neuroscience'],
  'brain': ['cerebro', 'neural', 'neuroscience'],
  'diabetes': ['diabetes', 'glucose', 'glucosa', 'insulin', 'insulina'],
  'corazon': ['heart', 'cardiac', 'cardiaco', 'cardiovascular', 'ecg'],
  'heart': ['corazon', 'cardiac', 'cardiovascular', 'ecg'],
  'protesis': ['prosthesis', 'prosthetic', 'prosthetics', 'protese'],
  'prosthesis': ['protesis', 'prosthetic', 'prosthetics', 'protese'],
  'biomecanica': ['biomechanics', 'biomechanical', 'biomecanica'],
  'biomechanics': ['biomecanica', 'biomechanical'],
  'ultrasonido': ['ultrasound', 'ultrasonic', 'ultrassom'],
  'ultrasound': ['ultrasonido', 'ultrasonic', 'ultrassom'],
  'resonancia magnetica': ['magnetic resonance', 'mri', 'ressonancia magnetica'],
  'mri': ['magnetic resonance', 'resonancia magnetica', 'ressonancia magnetica'],
  'tomografia': ['tomography', 'ct scan', 'tomografia'],
  'tomography': ['tomografia', 'ct scan'],
  'sensores': ['sensor', 'sensors', 'sensores', 'sensing'],
  'sensors': ['sensores', 'sensor', 'sensing'],
  'biosensores': ['biosensor', 'biosensors', 'biossensores'],
  'biosensors': ['biosensores', 'biosensor', 'biossensores'],
  'telemedicina': ['telemedicine', 'telehealth', 'e-health', 'ehealth', 'telemedicina'],
  'telemedicine': ['telemedicina', 'telehealth', 'e-health', 'ehealth'],
  'wearable': ['wearable', 'wearables', 'vestible', 'vestibles'],
  'electronica': ['electronics', 'electronic', 'eletronica'],
  'electronics': ['electronica', 'electronic', 'eletronica'],
  'materiales': ['materials', 'material', 'materiais', 'biomaterials', 'biomateriales'],
  'materials': ['materiales', 'material', 'materiais', 'biomaterials'],
  'tejidos': ['tissue', 'tissues', 'tecidos', 'tissue engineering'],
  'tissue engineering': ['ingenieria de tejidos', 'tejidos', 'engenharia de tecidos'],
  'celulas': ['cell', 'cells', 'cellular', 'celulas', 'celular'],
  'cells': ['celulas', 'cell', 'cellular'],
  'genetica': ['genetic', 'genetics', 'genetica', 'gene', 'genes'],
  'genetics': ['genetica', 'genetic', 'gene', 'genes'],
  'imagenes': ['image', 'images', 'imaging', 'imagens'],
  'images': ['imagenes', 'image', 'imaging', 'imagens'],
  'fisiologia': ['physiology', 'physiological', 'fisiologia'],
  'physiology': ['fisiologia', 'physiological'],
  'movimiento': ['movement', 'motion', 'movimento', 'gait', 'marcha'],
  'movement': ['movimiento', 'motion', 'movimento', 'gait'],
  'rayos x': ['x-ray', 'x ray', 'xray', 'radiography', 'radiografia'],
  'x-ray': ['rayos x', 'radiography', 'radiografia'],
  'covid-19': ['covid', 'coronavirus', 'sars-cov-2', 'pandemic', 'pandemia'],
  'ia generativa': ['generative ai', 'generative artificial intelligence', 'llm', 'large language model', 'chatgpt'],
  'modelos de lenguaje': ['language model', 'language models', 'llm', 'large language model', 'chatgpt', 'gpt'],
  'large language models': ['modelos de lenguaje', 'llm', 'language model', 'chatgpt', 'gpt'],
  'llm': ['large language model', 'language model', 'modelos de lenguaje', 'chatgpt'],
  'transformers': ['transformer', 'attention', 'bert', 'gpt'],
  'reinforcement learning': ['aprendizaje por refuerzo', 'aprendizaje reforzado', 'aprendizado por reforco'],
  'aprendizaje por refuerzo': ['reinforcement learning', 'aprendizaje reforzado'],
  'clasificacion': ['classification', 'classifier', 'clasificador', 'classificacao'],
  'classification': ['clasificacion', 'classifier', 'clasificador'],
  'clustering': ['clustering', 'agrupamiento', 'cluster', 'agrupamento'],
  'agrupamiento': ['clustering', 'cluster', 'agrupamento'],
  'prediccion': ['prediction', 'predictive', 'forecasting', 'pronostico', 'previsao'],
  'prediction': ['prediccion', 'predictive', 'forecasting', 'pronostico'],
  'deteccion de anomalias': ['anomaly detection', 'outlier detection', 'deteccao de anomalias'],
  'anomaly detection': ['deteccion de anomalias', 'outlier detection'],
  'evolutivo': ['evolutionary', 'evolucionario', 'evolutionary algorithm', 'evolutivo'],
  'evolutionary': ['evolutivo', 'evolucionario', 'evolutionary algorithm'],
  'computacion evolutiva': ['evolutionary computation', 'evolutionary algorithms', 'computacao evolutiva'],
  'evolutionary computation': ['computacion evolutiva', 'evolutionary algorithms'],
  'logica difusa': ['fuzzy logic', 'fuzzy', 'logica fuzzy', 'logica nebulosa'],
  'fuzzy logic': ['logica difusa', 'fuzzy', 'logica nebulosa'],
  'vision': ['vision', 'visao', 'visual'],
  'voz': ['speech', 'voice', 'voz', 'fala'],
  'speech': ['voz', 'voice', 'fala', 'speech recognition'],
  'texto': ['text', 'texto', 'textual'],
  'text': ['texto', 'textual'],
  'documentos': ['document', 'documents', 'documentos'],
  'documents': ['documentos', 'document'],
  'empresa': ['company', 'enterprise', 'business', 'empresa', 'negocio', 'negocios'],
  'empresas': ['company', 'companies', 'enterprise', 'business', 'empresa', 'negocios'],
  'business': ['empresa', 'empresas', 'negocio', 'negocios', 'enterprise'],
  'negocios': ['business', 'empresa', 'empresas', 'negocio'],
  'banco': ['bank', 'banking', 'banco', 'financiero', 'financial'],
  'finanzas': ['finance', 'financial', 'financiero', 'financas'],
  'finance': ['finanzas', 'financial', 'financiero', 'financas'],
  'agricultura': ['agriculture', 'agricultural', 'agro', 'agricola'],
  'agriculture': ['agricultura', 'agricultural', 'agro', 'agricola'],
  'medio ambiente': ['environment', 'environmental', 'ambiental', 'meio ambiente'],
  'ambiental': ['environmental', 'environment', 'medio ambiente', 'meio ambiente'],
  'environment': ['medio ambiente', 'ambiental', 'environmental'],
  'clima': ['climate', 'weather', 'clima', 'climatico'],
  'climate': ['clima', 'weather', 'climatico'],
  'agua': ['water', 'agua', 'hidrico', 'hydro'],
  'water': ['agua', 'hidrico', 'hydro'],
  'sismos': ['earthquake', 'earthquakes', 'seismic', 'sismico', 'terremoto', 'terremotos'],
  'terremotos': ['earthquake', 'earthquakes', 'seismic', 'sismico', 'sismos'],
  'earthquakes': ['sismos', 'terremotos', 'seismic', 'sismico'],
  'astronomia': ['astronomy', 'astronomical', 'astronomia', 'telescope', 'telescopio'],
  'astronomy': ['astronomia', 'astronomical', 'telescope', 'telescopio'],
  'deporte': ['sport', 'sports', 'deporte', 'deportes', 'esporte', 'futbol', 'football', 'soccer'],
  'sports': ['deporte', 'deportes', 'esporte', 'sport'],
  'musica': ['music', 'musica', 'audio'],
  'music': ['musica', 'audio'],
  'turismo': ['tourism', 'turismo', 'tourist'],
  'tourism': ['turismo', 'tourist'],
  'espanol': ['spanish'], 'ingles': ['english'], 'portugues': ['portuguese'], 'castellano': ['spanish']
};

/* Texto de la interfaz del asistente en tres idiomas */
const T = {
  es: { understood:'Entendí', noRows:'No hay datos para el filtro activo.', none:'No encontré nada con esas condiciones.', pubs:'publicaciones', pub1:'publicación', works:'trabajos de título', work1:'trabajo de título', years:'años', person:'persona', people:'personas', topic:'tema', quartile:'cuartil', index:'indexación', type:'tipo', program:'programa', country:'país', from:'desde', to:'hasta', ambiguous:'Hay más de una persona compatible con ese nombre. Escribe el nombre más completo:', needTwo:'Para comparar necesito dos personas de la base, por ejemplo “compara a X con Y”.', asGuide:'como guía', asCoguide:'como co-guía', withLink:'con enlace al repositorio', withoutLink:'sin enlace al repositorio', together:'en conjunto', journal:'artículos de revista', conference:'actas de congreso', other:'otros documentos', wos:'WoS', scopus:'Scopus', both:'WoS y Scopus', onlyScopus:'solo Scopus', onlyWos:'solo WoS', lastN:'últimos {n} años' },
  en: { understood:'Understood', noRows:'No data for the active filter.', none:'Nothing matches those conditions.', pubs:'publications', pub1:'publication', works:'final projects', work1:'final project', years:'years', person:'person', people:'people', topic:'topic', quartile:'quartile', index:'indexing', type:'type', program:'program', country:'country', from:'from', to:'until', ambiguous:'More than one person matches that name. Type a fuller name:', needTwo:'To compare I need two people in the database, e.g. “compare X with Y”.', asGuide:'as advisor', asCoguide:'as co-advisor', withLink:'with repository link', withoutLink:'without repository link', together:'together', journal:'journal articles', conference:'conference proceedings', other:'other documents', wos:'WoS', scopus:'Scopus', both:'WoS and Scopus', onlyScopus:'Scopus only', onlyWos:'WoS only', lastN:'last {n} years' },
  pt: { understood:'Entendi', noRows:'Não há dados para o filtro ativo.', none:'Não encontrei nada com essas condições.', pubs:'publicações', pub1:'publicação', works:'trabalhos de conclusão', work1:'trabalho de conclusão', years:'anos', person:'pessoa', people:'pessoas', topic:'tema', quartile:'quartil', index:'indexação', type:'tipo', program:'programa', country:'país', from:'desde', to:'até', ambiguous:'Há mais de uma pessoa compatível com esse nome. Escreva o nome mais completo:', needTwo:'Para comparar preciso de duas pessoas da base, por exemplo “compare X com Y”.', asGuide:'como orientador(a)', asCoguide:'como coorientador(a)', withLink:'com link do repositório', withoutLink:'sem link do repositório', together:'em conjunto', journal:'artigos de revista', conference:'anais de congresso', other:'outros documentos', wos:'WoS', scopus:'Scopus', both:'WoS e Scopus', onlyScopus:'só Scopus', onlyWos:'só WoS', lastN:'últimos {n} anos' }
};

/* ---------- reconocimiento de intención ----------
   Orden: la primera que calza gana. Cada intención indica qué función del
   módulo necesita (si el módulo no la tiene, se salta a la siguiente). */
const INTENTS = [
  ['ayuda',     /^(ayuda|help|ajuda)\b|^(hola|hello|hi|oi|ola|buenas|buenos dias|buenas tardes)[\s!?.,]*$|\b(que puedes hacer|que sabes hacer|como funciona|que puedo preguntar|what can you do|how does this work|what can i ask|o que voce faz|o que sabe fazer|o que posso perguntar)\b/, 'ayuda'],
  ['definir',   /\b(define|definir|defina|definicion|definiciones|definicao|definition|definitions|que es|que son|que significa\w*|significado|explica|explicame|explique|meaning|means|what is|what are|what does|what do .* mean|o que e|o que sao|o que significa\w*)\b/, 'definir'],
  ['comparar',  /\b(compara|comparar|comparacion|comparame|compare|comparison|versus|vs|contra|frente a)\b/, 'comparar'],
  ['paises',    /\b(paises|countries|por pais|by country|per country|internacional|internacionales|international|internacionais|extranjero|exterior|mapa|colaboracion internacional)\b/, 'paisesResumen'],
  ['coautores', /\b(coautor\w*|co autor\w*|coauthor\w*|co author\w*|colabora|colaboran|colaboradores|colaboracion|colaboraciones|colaboracao|colaboracoes|collaboration|collaborations|collaborators|collaborates|coguia\w*|co guia\w*|co-guia\w*|coorienta\w*|co orienta\w*|co-orienta\w*|coadvis\w*|co advis\w*|co-advis\w*|cosupervis\w*|co supervis\w*|co-supervis\w*|parceir\w*)\b/, 'coautores'],
  ['fuentes',   /\b(en que (revistas?|congresos?|conferencias?|fuentes?)|que revistas|cuales revistas|cuales son las revistas|revistas (mas|frecuentes|principales|donde|en las que|con mas|de|en que)|principales revistas|top revistas|which (journals?|conferences?|venues?)|what (journals?|conferences?)|journals? (most|where|with|of)|top journals|main journals|em que (revistas?|congressos?|conferencias?)|quais revistas|revistas (mais|onde|em que)|principais revistas|fuentes|fontes|sources|venues?|donde publica\w*|where do(es)? .* publish|onde publica\w*|congresos (mas|frecuentes|principales|de)|conferencias (mas|frecuentes|principales)|top (conferencias|congresos|conferences)|main conferences)\b/, 'fuentes'],
  ['evolucion', /\b(por ano|por anio|por anos|cada ano|cada anio|evolucion|evolucao|tendencia|trend|over time|by year|per year|a lo largo|serie|historico|historial|timeline|linea de tiempo|ano a ano|anio a anio|anualmente|yearly|annual)\b/, 'evolucion'],
  ['programas', /\b(programas|carreras|por programa|por carrera|by program|by programme|per program|por curso|por nivel|niveles|pregrado y posgrado|undergraduate and graduate|por tipo de programa)\b/, 'programasResumen'],
  ['ranking',   /\b(ranking|rankings|quien|quienes|who|quem|mas productivo|mas productivos|mas productiva|mas productivas|most productive|productividad|lideran|lidera|top (autores|academicos|academicas|guias|profesores|investigadores|authors|academics|advisors|researchers|orientadores|pessoas|personas)|mejores (autores|academicos|guias)|con mas|with most|with more|com mais|que mas publica|que mas publican|que mas dirige|que mas dirigen|que mas guia|que mas guian|mais produtivo|mais produtivos)\b/, 'ranking'],
  ['temas',     /\b(tema|temas|topic|topics|linea|lineas|area|areas|palabra clave|palabras clave|keyword|keywords|palavra chave|palavras chave|especialidad|especialidades|dominio|dominios|nube de palabras|assunto|assuntos)\b/, 'temas'],
  ['cuartiles', /\b(cuartiles|quartis|quartiles|por cuartil|por quartil|by quartile|distribucion por cuartil|distribucion de cuartiles)\b/, 'cuartiles'],
  ['metricas',  /\b(indice h|h index|h-index|hindex|promedio|average|mean|estadistica|estadisticas|metrica|metricas|metric|metrics|cuantas citas|how many citations|quantas citacoes|citas totales|total de citas|total citations|perfil|profile|resumen de|summary of|resumo de|quien es|who is|quem e)\b/, 'metricas'],
  ['contar',    /\b(cuantas|cuantos|cuanta|cuanto|how many|how much|quantas|quantos|numero de|number of|total de|total of|cantidad de|conteo|count)\b/, null],
  ['top',       /\b(mas citad\w*|more cited|most cited|mais citad\w*|top citad\w*|top cited|top|citas|cited|citadas|citados|citacoes|influyente|influyentes|destacad\w*)\b/, 'listaTop'],
  ['listar',    /\b(lista|listar|listame|list|muestra|muestrame|mostrar|show|ver|dame|busca|buscar|buscame|search|find|encuentra|procura|procurar|mostre|mostra|liste|todas|todos|cuales|which|quais|ultimas|ultimos|recientes|recent|latest|newest|mais recentes)\b/, null]
];

function createEngine(cfg) {
  const lang = () => (cfg.lang ? cfg.lang() : 'es');
  const L = () => T[lang()] || T.es;
  const isPub = cfg.modulo === 'publicaciones';
  const sin = Object.assign({}, SINONIMOS, cfg.sinonimos || {});

  /* ---------- personas (nombres de la unidad) ---------- */
  function personas() { return cfg.personas(); }
  function nombreTokens(name) { return words(name).filter(t => t.length > 1); }
  /* Busca personas mencionadas en la pregunta. Devuelve candidatos ordenados y los tokens que usó. */
  function buscarPersonas(q) {
    const toks = uniq(words(q).filter(t => t.length > 2 && !STOP.has(t) && !/^\d+$/.test(t)));
    if (!toks.length) return { lista: [], usados: [] };
    const nq = norm(q);
    const res = [];
    personas().forEach(name => {
      const nt = nombreTokens(name); if (!nt.length) return;
      const na = nt.join(' ');
      let score = 0; const usados = [];
      if (nq.includes(na)) score += 200;
      toks.forEach(t => {
        if (nt.includes(t)) { score += 40 + (t === nt[nt.length - 1] || t === nt[nt.length - 2] ? 25 : 0) + (t === nt[0] ? 10 : 0); usados.push(t); }
        else if (t.length >= 4 && nt.some(w => w.length >= 5 && (w.startsWith(t) || t.startsWith(w)))) { score += 18; usados.push(t); }
      });
      if (usados.length >= 2) score += 40;
      if (score > 0) res.push({ name, score, usados: uniq(usados) });
    });
    res.sort((a, b) => b.score - a.score || a.name.localeCompare(b.name));
    return { lista: res, usados: uniq(res.flatMap(r => r.usados)) };
  }
  /* Decide: ninguna persona, una persona clara, dos (para comparar o coautoría) o ambigüedad. */
  function resolverPersonas(q, intent) {
    const { lista } = buscarPersonas(q);
    if (!lista.length) return { personas: [], ambiguas: [], usados: [] };
    const top = lista[0].score;
    const fuertes = lista.filter(x => x.score >= 40);
    if (!fuertes.length) return { personas: [], ambiguas: [], usados: [] };
    /* dos apellidos distintos en la pregunta: dos personas distintas (comparar, coautoría conjunta) */
    const porToken = new Map();
    fuertes.forEach(c => c.usados.forEach(t => { if (!porToken.has(t)) porToken.set(t, []); porToken.get(t).push(c); }));
    const grupos = [...porToken.values()];
    if (grupos.length >= 2 && (intent === 'comparar' || /\b(y|and|e|con|with|com|junto|juntos|together|entre|between)\b/.test(norm(q)))) {
      const elegidos = [];
      grupos.forEach(g => { const b = g.sort((a, b) => b.score - a.score)[0]; if (b && !elegidos.includes(b.name)) elegidos.push(b.name); });
      if (elegidos.length >= 2) return { personas: elegidos.slice(0, 2), ambiguas: [], usados: [...porToken.keys()] };
    }
    const empate = fuertes.filter(x => x.score >= top - 10);
    if (empate.length > 1) {
      /* mismo apellido en varias personas: ambigüedad real, salvo que un nombre completo calce */
      const exacto = empate.find(x => x.score >= 200);
      if (exacto) return { personas: [exacto.name], ambiguas: [], usados: exacto.usados };
      return { personas: [], ambiguas: empate.map(x => x.name).slice(0, 6), usados: uniq(empate.flatMap(x => x.usados)) };
    }
    return { personas: [fuertes[0].name], ambiguas: [], usados: fuertes[0].usados };
  }

  /* ---------- condiciones ---------- */
  function extraerAnios(nq) {
    const hoy = new Date().getFullYear();
    const yrs = [...nq.matchAll(/\b(19[5-9]\d|20[0-4]\d)\b/g)].map(m => parseInt(m[0], 10));
    let m;
    if ((m = nq.match(/\b(ultimos|ultimas|last|nos ultimos|nas ultimas)\s+(\d{1,2})\s+(anos|anios|years)\b/))) { const n = parseInt(m[2], 10); return { min: hoy - n + 1, max: hoy, texto: L().lastN.replace('{n}', n) }; }
    if (/\b(este ano|este anio|this year|neste ano)\b/.test(nq)) return { min: hoy, max: hoy, texto: String(hoy) };
    if (/\b(ano pasado|anio pasado|last year|ano passado)\b/.test(nq)) return { min: hoy - 1, max: hoy - 1, texto: String(hoy - 1) };
    if (!yrs.length) return null;
    if (yrs.length >= 2) return { min: Math.min(...yrs), max: Math.max(...yrs), texto: Math.min(...yrs) + '–' + Math.max(...yrs) };
    const y = yrs[0];
    if (/\b(desde|from|since|a partir de|apos|despues de|despues del|after)\b/.test(nq) && !/\b(hasta|until|ate)\b/.test(nq)) return { min: y, max: 2100, texto: L().from + ' ' + y };
    if (/\b(hasta|until|before|antes de|antes del|ate)\b/.test(nq)) return { min: 0, max: y, texto: L().to + ' ' + y };
    return { min: y, max: y, texto: String(y) };
  }
  function extraerCuartil(nq) {
    const m = nq.match(/\b(q\s?([1-4])|cuartil ([1-4])|quartil ([1-4])|quartile ([1-4])|(primer|segundo|tercer|cuarto) cuartil|(first|second|third|fourth) quartile|(primeiro|segundo|terceiro|quarto) quartil)\b/);
    if (!m) return null;
    const ord = { primer: 1, primeiro: 1, segundo: 2, tercer: 3, terceiro: 3, cuarto: 4, quarto: 4, first: 1, second: 2, third: 3, fourth: 4 };
    const n = m[2] || m[3] || m[4] || m[5] || ord[m[6]] || ord[m[7]] || ord[m[8]];
    return n ? 'Q' + n : null;
  }
  function extraerIndex(nq) {
    const wos = /\b(wos|web of science|isi)\b/.test(nq), sc = /\bscopus\b/.test(nq);
    if (wos && sc) return 'ambas';
    if (wos) return /\b(solo|only|so|apenas|unicamente|solamente)\b/.test(nq) ? 'solowos' : 'wos';
    if (sc) return /\b(solo|only|so|apenas|unicamente|solamente)\b/.test(nq) ? 'soloscopus' : 'scopus';
    return null;
  }
  function extraerTipo(nq) {
    if (/\b(acta|actas|conferencia|conferencias|congreso|congresos|congresso|congressos|conference|conferences|proceedings|anais)\b/.test(nq)) return 'actas';
    if (/\b(articulo|articulos|artigo|artigos|article|articles|revista|revistas|journal|journals)\b/.test(nq)) return 'revista';
    if (/\b(libro|libros|capitulo|capitulos|book|books|chapter|chapters|livro|livros)\b/.test(nq)) return 'otro';
    return null;
  }
  function extraerLimite(nq, porDefecto) {
    const m = nq.match(/\b(top|primeras|primeros|primeiras|primeiros|first|las|los|the|as|os)\s+(\d{1,2})\b/) || nq.match(/\b(\d{1,2})\s+(mas|most|mais|publicaciones|papers|trabajos|memorias|tesis|autores|academicos|guias|revistas|paises|coautores|publications|works|authors|countries|journals)\b/);
    if (m) return Math.max(1, Math.min(50, parseInt(m[2] || m[1], 10)));
    if (/\b(todas|todos|all|completa|completo|toda|todo)\b/.test(nq)) return Infinity;
    return porDefecto;
  }
  function extraerPrograma(nq) {
    if (!cfg.programas) return null;
    for (const [clave, patron] of cfg.programas) if (patron.test(nq)) return clave;
    return null;
  }
  function extraerPais(nq) {
    if (!cfg.paises) return null;
    let mejor = null;
    cfg.paises().forEach(([alias, canon]) => { if (new RegExp('\\b' + reEsc(alias) + '\\b').test(nq) && (!mejor || alias.length > mejor[0].length)) mejor = [alias, canon]; });
    return mejor ? mejor[1] : null;
  }
  const ROL_RE = /\b(como (guia|guias|tutor|director|orientador|orientadora)|as (advisor|supervisor|main advisor)|como (coguia|coguias|co-guia|co-guias|co guia|cotutor|coorientador|coorientadora|co-orientador)|as (co-advisor|coadvisor|co advisor|co-supervisor))\b/;
  function extraerRol(nq) {
    if (!cfg.rolDe) return null;
    const m = nq.match(ROL_RE); if (!m) return null;
    return /co[\s-]?(guia|tutor|orient|advis|supervis)/.test(m[0]) ? 'coguia' : 'guia';
  }
  function extraerEnlace(nq) {
    if (!cfg.enlace) return null;
    if (/\b(sin enlace|sin link|no tienen enlace|without link|without a link|sem link|faltan enlace|falta enlace|sin repositorio|no estan en el repositorio)\b/.test(nq)) return false;
    if (/\b(con enlace|con link|with link|with a link|com link|en el repositorio|publicadas en el repositorio|in the repository)\b/.test(nq)) return true;
    return null;
  }
  /* El tema es lo que queda de la pregunta después de quitar intención, nombres, años y palabras vacías */
  function extraerTema(nq, usadosPersona, condiciones) {
    let s = ' ' + nq + ' ';
    INTENTS.forEach(([, re]) => { s = s.replace(new RegExp(re.source.replace(/\^/g, '\\b'), 'g'), ' '); });
    s = s.replace(/\b(19[5-9]\d|20[0-4]\d)\b/g, ' ').replace(/\b(q\s?[1-4]|wos|web of science|scopus|isi|cuartil [1-4]|quartil [1-4]|quartile [1-4])\b/g, ' ');
    s = s.replace(/\b(desde|hasta|entre|from|to|since|until|between|ate|ultimos|ultimas|last|este|pasado|anos|anios|years|ano|anio|year|solo|only|apenas|unicamente|solamente)\b/g, ' ');
    if (condiciones.tipo) s = s.replace(/\b(articulo|articulos|artigo|artigos|article|articles|revista|revistas|journal|journals|acta|actas|conferencia|conferencias|congreso|congresos|congresso|congressos|conference|conferences|proceedings|anais|libro|libros|capitulo|capitulos|book|books|chapter|chapters|livro|livros)\b/g, ' ');
    if (condiciones.programa && cfg.programas) cfg.programas.forEach(([, re]) => { s = s.replace(new RegExp(re.source, 'g'), ' '); });
    if (condiciones.pais && cfg.paises) cfg.paises().forEach(([alias]) => { s = s.replace(new RegExp('\\b' + reEsc(alias) + '\\b', 'g'), ' '); });
    s = s.replace(/\b(sin enlace|con enlace|sin link|con link|repositorio|repository|with link|without link|com link|sem link)\b/g, ' ');
    s = s.replace(/\b(en conjunto|em conjunto|conjunt\w*|junt\w*|en comun|in common|together|ambos|ambas|both)\b/g, ' ');
    const toks = words(s).filter(t => t.length > 2 && !STOP.has(t) && !usadosPersona.includes(t) && !/^\d+$/.test(t));
    if (!toks.length) return null;
    const frase = toks.join(' ');
    const variantes = new Set([frase]);
    let resto = [];
    /* sinónimos: si la frase completa es una clave, se usan sus equivalentes; si no, la clave más larga que
       aparezca como palabra(s) enteras (“videojuegos” no activa “juegos”) y el resto de palabras se exige aparte */
    if (sin[frase]) sin[frase].forEach(v => variantes.add(norm(v)));
    else {
      const sub = Object.keys(sin).map(norm).filter(nk => nk.length > 3 && new RegExp('\\b' + reEsc(nk) + '\\b').test(frase)).sort((a, b) => b.length - a.length)[0];
      if (sub) {
        variantes.add(sub); (sin[sub] || []).forEach(v => variantes.add(norm(v)));
        const ws = new Set(words(sub));
        resto = toks.filter(t => !ws.has(t));
      }
    }
    return { texto: frase, tokens: toks, variantes: [...variantes], resto };
  }

  /* ---------- aplicar condiciones ---------- */
  function filtrar(rows, c) {
    let out = rows;
    if (c.anios) out = out.filter(r => { const y = cfg.anio(r); return y >= c.anios.min && y <= c.anios.max; });
    if (c.cuartil && cfg.cuartil) out = out.filter(r => cfg.cuartil(r) === c.cuartil);
    if (c.index && cfg.wos) out = out.filter(r => {
      const w = cfg.wos(r), s = cfg.scopus(r);
      return c.index === 'wos' ? w : c.index === 'scopus' ? s : c.index === 'ambas' ? (w && s) : c.index === 'solowos' ? (w && !s) : (s && !w);
    });
    if (c.tipo && cfg.tipo) out = out.filter(r => cfg.tipo(r) === c.tipo);
    if (c.programa && cfg.programaDe) out = out.filter(r => cfg.programaDe(r).includes(c.programa));
    if (c.pais && cfg.paisesDe) out = out.filter(r => cfg.paisesDe(r).includes(c.pais));
    if (c.enlace !== null && c.enlace !== undefined && cfg.enlace) out = out.filter(r => cfg.enlace(r) === c.enlace);
    if (c.personas.length === 1) out = out.filter(r => (c.rol && cfg.rolDe) ? cfg.rolDe(r, c.personas[0], c.rol) : cfg.dePersona(r, c.personas[0]));
    if (c.personas.length === 2 && c.conjunto === 'union') out = out.filter(r => cfg.dePersona(r, c.personas[0]) || cfg.dePersona(r, c.personas[1]));
    if (c.personas.length === 2 && c.conjunto === 'ambos') {
      const key = cfg.clave || (r => r);
      const [a, b] = c.personas;
      const ka = new Set(out.filter(r => cfg.dePersona(r, a)).map(key)), kb = new Set(out.filter(r => cfg.dePersona(r, b)).map(key));
      out = out.filter(r => (cfg.dePersona(r, a) || cfg.dePersona(r, b)) && ka.has(key(r)) && kb.has(key(r)));
    }
    if (c.tema) out = buscarTema(out, c.tema);
    else if (cfg.orden) out = [...out].sort(cfg.orden);
    return out;
  }
  /* Búsqueda de tema: una variante completa (frase o sinónimo) o todos los tokens, con puntaje por campo */
  function buscarTema(rows, tema) {
    const scored = [];
    const resto = tema.resto || [];
    rows.forEach(r => {
      const p = cfg.texto(r); let score = 0;
      if (resto.length && !resto.every(t => has(p.todo, t))) return;
      tema.variantes.forEach(v => { if (has(p.titulo, v)) score += 6; if (has(p.claves, v)) score += 8; if (has(p.resumen, v)) score += 3; if (has(p.areas, v)) score += 3; });
      /* sin frase exacta: todas las palabras dentro de un mismo campo (título, claves, resumen o áreas) */
      if (!score && tema.tokens.length > 1) {
        const campo = ['titulo', 'claves', 'resumen', 'areas'].find(f => tema.tokens.every(t => has(p[f], t)));
        if (campo) score = ({ titulo: 4, claves: 4, resumen: 2, areas: 2 })[campo];
      }
      /* una sola palabra que no está en los campos principales: vale si aparece en cualquier otro campo */
      if (!score && tema.tokens.length === 1 && has(p.todo, tema.tokens[0])) score = 1;
      if (score) scored.push({ r, score });
    });
    scored.sort((a, b) => b.score - a.score || (cfg.orden ? cfg.orden(a.r, b.r) : 0));
    return scored.map(x => x.r);
  }
  /* Publicaciones únicas (en tesis cada fila ya es un trabajo) */
  const unico = rows => cfg.unico ? cfg.unico(rows) : rows;

  /* ---------- descripción de lo entendido ---------- */
  function describir(c) {
    const l = L(); const partes = [];
    if (c.personas.length) partes.push((c.personas.length === 2 ? l.people : l.person) + ': ' + c.personas.map(cfg.nombre).join(c.conjunto === 'ambos' ? ' + ' : ', ') + (c.conjunto === 'ambos' ? ' (' + l.together + ')' : '') + (c.rol && c.personas.length === 1 ? ' (' + (c.rol === 'guia' ? l.asGuide : l.asCoguide) + ')' : ''));
    if (c.anios) partes.push(l.years + ': ' + c.anios.texto);
    if (c.cuartil) partes.push(l.quartile + ': ' + c.cuartil);
    if (c.index) partes.push(l.index + ': ' + ({ wos: l.wos, scopus: l.scopus, ambas: l.both, solowos: l.onlyWos, soloscopus: l.onlyScopus })[c.index]);
    if (c.tipo) partes.push(l.type + ': ' + ({ revista: l.journal, actas: l.conference, otro: l.other })[c.tipo]);
    if (c.programa && cfg.programaNombre) partes.push(l.program + ': ' + cfg.programaNombre(c.programa));
    if (c.pais) partes.push(l.country + ': ' + c.pais);
    if (c.enlace === true) partes.push(l.withLink); if (c.enlace === false) partes.push(l.withoutLink);
    if (c.tema) partes.push(l.topic + ': “' + c.tema.texto + '”');
    return partes.length ? `<p class="chat-understood"><span>${esc(l.understood)}:</span> ${partes.map(esc).join(' · ')}</p>` : '';
  }
  const resultado = (n, unidad) => { const l = L(); const u = n === 1 ? (isPub ? l.pub1 : l.work1) : unidad; return `<p class="chat-result"><b>${fmtN(n, lang())}</b> ${esc(u)}</p>`; };

  /* ---------- respuestas ---------- */
  function responder(q) {
    const l = L();
    const nqFull = norm(q);
    const rol = extraerRol(nqFull);
    const nq = rol ? nqFull.replace(ROL_RE, ' ').replace(/\s+/g, ' ').trim() : nqFull;   /* “como co-guía” es una condición, no una intención */
    const base = cfg.filas();
    if (!nq) return cfg.ayuda();

    /* intención (saltando las que el módulo no puede responder) */
    let intent = null;
    for (const [name, re, necesita] of INTENTS) {
      if (!re.test(nq) || (necesita && !cfg[necesita])) continue;
      if (name === 'definir') { const d = cfg.definir(q); if (d) return d; continue; }   /* sin término del glosario: sigue con otra intención */
      intent = name; break;
    }
    if (intent === 'ayuda') return cfg.ayuda();
    if (!base.length) return `<p>${esc(l.noRows)}</p>`;

    /* condiciones */
    const rp = resolverPersonas(q, intent);
    if (rp.ambiguas.length) return `<p>${esc(l.ambiguous)}</p><div class="chat-pubs">${rp.ambiguas.map(a => `<article class="chat-pub"><div class="chat-pub-title">${esc(cfg.nombre(a))}</div></article>`).join('')}</div>`;
    const juntos = /\b(junt\w*|conjunt\w*|en comun|in common|together|ambos|ambas|both)\b/.test(nq);
    const c = { personas: rp.personas, conjunto: rp.personas.length === 2 && intent !== 'comparar' ? (juntos ? 'ambos' : 'union') : false, rol, anios: extraerAnios(nq), cuartil: extraerCuartil(nq), index: extraerIndex(nq), tipo: null, programa: extraerPrograma(nq), pais: extraerPais(nq), enlace: extraerEnlace(nq), tema: null };
    if (intent !== 'fuentes') c.tipo = extraerTipo(nq);
    c.tema = extraerTema(nq, rp.usados, c);
    const unidad = isPub ? l.pubs : l.works;
    const hayCondicion = c.personas.length || c.tema || c.anios || c.cuartil || c.index || c.tipo || c.programa || c.pais || c.enlace !== null;

    /* ajustes: la intención se corrige con lo que hay en la pregunta */
    if (!intent) intent = (c.personas.length === 2 && !c.conjunto) ? 'comparar' : hayCondicion ? 'listar' : 'buscar';
    if (intent === 'paises' && c.pais) intent = 'listar';
    if (intent === 'temas' && c.tema) intent = 'listar';
    if (intent === 'ranking' && c.personas.length === 1) intent = 'listar';
    if (intent === 'contar' && c.personas.length === 2 && c.conjunto !== 'ambos') c.conjunto = 'ambos';

    if (intent === 'comparar') {
      if (c.personas.length < 2) return `<p>${esc(l.needTwo)}</p>`;
      const cc = Object.assign({}, c, { personas: [], conjunto: false });
      return describir(c) + cfg.comparar(filtrar(base, cc), c.personas[0], c.personas[1]);
    }
    if (intent === 'coautores') {
      if (!c.personas.length) return describir(c) + cfg.coautores(filtrar(base, c), null);
      const persona = c.personas[0];
      const cc = Object.assign({}, c, { personas: [], conjunto: false });
      const rows = filtrar(base, cc).filter(r => cfg.dePersona(r, persona));
      return describir(Object.assign({}, c, { personas: [persona], conjunto: false })) + cfg.coautores(rows, persona);
    }

    const rows = filtrar(base, c);
    const n = unico(rows).length;
    const cab = describir(c);
    if (!rows.length && intent !== 'buscar') return cab + `<p>${esc(l.none)}</p>` + (cfg.sugerencias ? cfg.sugerencias(q, c) : '');

    switch (intent) {
      case 'contar': return cab + resultado(n, unidad) + (cfg.resumenCorto ? cfg.resumenCorto(rows, c) : '');
      case 'top': return cab + resultado(n, unidad) + cfg.listaTop(rows, extraerLimite(nq, 10));
      case 'ranking': return cab + resultado(n, unidad) + cfg.ranking(rows, c, extraerLimite(nq, 12));
      case 'temas': return cab + resultado(n, unidad) + cfg.temas(rows);
      case 'evolucion': return cab + resultado(n, unidad) + cfg.evolucion(rows);
      case 'fuentes': return cab + resultado(n, unidad) + cfg.fuentes(rows, extraerLimite(nq, 12));
      case 'paises': return cab + resultado(n, unidad) + cfg.paisesResumen(rows, extraerLimite(nq, 15));
      case 'programas': return cab + resultado(n, unidad) + cfg.programasResumen(rows);
      case 'cuartiles': return cab + resultado(n, unidad) + cfg.cuartiles(rows);
      case 'metricas': return cab + resultado(n, unidad) + cfg.metricas(rows, c) + (c.personas.length === 1 ? cfg.lista(rows, extraerLimite(nq, 8)) : '');
      case 'listar': return cab + resultado(n, unidad) + (c.personas.length === 1 && cfg.metricas ? cfg.metricas(rows, c) : '') + cfg.lista(rows, extraerLimite(nq, 12));
      default: {
        /* búsqueda libre en todos los campos */
        const tema = c.tema || extraerTema(nq, [], c);
        if (!tema) return cfg.ayuda();
        const hits = buscarTema(base, tema);
        const nn = unico(hits).length;
        return describir(Object.assign({}, c, { tema })) + resultado(nn, unidad) + (nn ? cfg.lista(hits, extraerLimite(nq, 12)) : (cfg.sugerencias ? cfg.sugerencias(q, c) : ''));
      }
    }
  }

  return { responder, norm, esc, count, uniq, int, has, fmt: n => fmtN(n, lang()), T: L, buscarPersonas, filtrar };
}

window.Asistente = { crear: createEngine, norm, esc, count, uniq, int, has, SINONIMOS, STOP };
})();
