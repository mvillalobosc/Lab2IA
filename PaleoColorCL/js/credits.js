/**
 * Créditos y marca institucional. Se usan en el visor, en el editor y en el pie de cada
 * plantilla imprimible. Un solo lugar para cambiarlos.
 */
export const APP_NAME = "PaleoColor CL";

export const BRAND = Object.freeze({
  logo: "assets/brand/diinf.png",
  unit: "Departamento de Ingeniería Informática",
  faculty: "Facultad de Ingeniería · Universidad de Santiago de Chile",
  teal: "#00A79A",
  orange: "#EA7600",
  slate: "#394049",
});

/**
 * Cita de la memoria de origen, tal cual fue entregada.
 * OJO: el año dice "306 d. C.", que es un error del catálogo. Corregir acá cuando se sepa
 * el año real: se propaga al pie de todas las plantillas y a ambas aplicaciones.
 */
export const CITATION = Object.freeze({
  authors: "Rodríguez Zamorano, A. A., Villalobos Cid, M. J., & Universidad de Santiago de Chile. "
    + "Facultad de Ingeniería. Departamento de Ingeniería Informática.",
  year: "306 d. C.",
  title: "Desarrollo de un prototipo de módulo de realidad aumentada, para un sistema de "
    + "visualización interactiva con fines pedagógicos.",
  publisher: "Universidad de Santiago de Chile.",
});

/**
 * A quién escribirle si un dato está malo.
 *
 * Los 91 datos están verificados en fuente, pero la paleontología se mueve: Gondwananectes se
 * publicó en 2026 y cambió lo que se sabía. Un dato viejo o equivocado impreso en una hoja que
 * se lleva un niño no tiene vuelta atrás si nadie sabe a quién avisarle.
 */
export const CONTACT = Object.freeze({
  email: "manuel.villalobos@usach.cl",
  note: "¿Encontraste un error en los datos? Escríbenos a",
});

export function contactText() {
  return `${CONTACT.note} ${CONTACT.email}`;
}

export function citationText() {
  return `${CITATION.authors} (${CITATION.year}). ${CITATION.title} ${CITATION.publisher}`;
}

/** Cita partida en líneas para el pie de la hoja imprimible. */
export function citationLines() {
  return [
    `${CITATION.authors} (${CITATION.year}).`,
    CITATION.title,
    CITATION.publisher,
  ];
}
